# DigiforgeDynamics CCTV — Signaling Server

Relays WebRTC pairing/signaling messages between the camera app and viewer app.
It never sees the actual video — that flows peer-to-peer once WebRTC connects.

## Run locally
```
npm install
npm start
```
Server starts on port 3000 (override with `PORT` env var).

## Deploy
Deploy anywhere that runs Node (Railway, Render, Fly.io, a small VPS, etc.).
Once deployed, put its public HTTPS URL into both apps'
`lib/config/app_config.dart` as `signalingServerUrl`.

## Endpoints
- `GET /health` — status check
- `POST /pairing/create` — returns `{ pairingCode }`
- Socket.IO events: `register-camera`, `register-viewer`, `signal`, `viewer-joined`, `peer-disconnected`, `pairing-error`
