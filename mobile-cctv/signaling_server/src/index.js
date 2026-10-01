// DigiforgeDynamics CCTV — signaling server
// Relays WebRTC offer/answer/ICE messages between one camera device and one viewer device
// paired via a short-lived pairing code. Does not touch the video/audio stream itself —
// once WebRTC connects, media flows peer-to-peer.

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const { customAlphabet } = require('nanoid');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const nanoid = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 6);

// pairingCode -> { cameraSocketId, viewerSocketId, createdAt }
const rooms = new Map();

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'digiforge-cctv-signaling', activeRooms: rooms.size });
});

app.post('/pairing/create', (req, res) => {
  const code = nanoid();
  rooms.set(code, { cameraSocketId: null, viewerSocketId: null, createdAt: Date.now() });
  res.json({ pairingCode: code });
});

io.on('connection', (socket) => {
  socket.on('register-camera', ({ pairingCode }) => {
    const room = rooms.get(pairingCode);
    if (!room) return socket.emit('pairing-error', { message: 'Invalid or expired pairing code' });
    room.cameraSocketId = socket.id;
    socket.join(pairingCode);
    socket.data.pairingCode = pairingCode;
    socket.data.role = 'camera';
    socket.emit('registered', { role: 'camera', pairingCode });
  });

  socket.on('register-viewer', ({ pairingCode }) => {
    const room = rooms.get(pairingCode);
    if (!room) return socket.emit('pairing-error', { message: 'Invalid or expired pairing code' });
    room.viewerSocketId = socket.id;
    socket.join(pairingCode);
    socket.data.pairingCode = pairingCode;
    socket.data.role = 'viewer';
    socket.emit('registered', { role: 'viewer', pairingCode });
    if (room.cameraSocketId) {
      io.to(room.cameraSocketId).emit('viewer-joined', { pairingCode });
    }
  });

  socket.on('signal', ({ pairingCode, data }) => {
    socket.to(pairingCode).emit('signal', { data, from: socket.data.role });
  });

  socket.on('disconnect', () => {
    const code = socket.data.pairingCode;
    if (!code) return;
    const room = rooms.get(code);
    if (!room) return;
    if (socket.data.role === 'camera') room.cameraSocketId = null;
    if (socket.data.role === 'viewer') room.viewerSocketId = null;
    socket.to(code).emit('peer-disconnected', { role: socket.data.role });
    if (!room.cameraSocketId && !room.viewerSocketId) rooms.delete(code);
  });
});

// Sweep unpaired rooms older than 1 hour
setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms.entries()) {
    if (now - room.createdAt > 3600_000 && !room.cameraSocketId && !room.viewerSocketId) {
      rooms.delete(code);
    }
  }
}, 600_000);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Digiforge CCTV signaling server listening on port ${PORT}`));
