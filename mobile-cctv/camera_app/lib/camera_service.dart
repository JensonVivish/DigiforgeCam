import 'dart:async';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Modest capture settings: friendly to older phones, battery and mobile upload.
const int kCaptureWidth = 640;
const int kCaptureHeight = 480;
const int kCaptureFps = 15;

/// Camera side: captures video+audio, publishes presence, answers viewer offers
/// through Firebase RTDB signaling, then streams peer-to-peer.
/// Started from main(), not from a widget, so it also runs with no screen.
class CameraService extends ChangeNotifier {
  final Rtdb _db = Rtdb();
  final RTCVideoRenderer renderer = RTCVideoRenderer();

  String code = '------';
  MediaStream? stream;
  String? error;
  int viewers = 0;
  String facing = 'environment'; // 'environment' = back, 'user' = front
  VoidCallback? onReady; // fired once, when the camera first comes up
  bool _readyFired = false;
  bool started = false;

  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCDataChannel> _channels = {};
  final Set<String> _handled = {};
  final Set<String> _connected = {};
  final Map<String, Set<String>> _seen = {};
  List<Map<String, dynamic>> _ice = [];

  Timer? _poll;
  Timer? _beat;
  Timer? _watch;
  bool _polling = false;
  bool _rendererReady = false;
  bool _disposed = false;
  bool _restarting = false;
  Future<bool>? _opening;
  int _lastFrames = -1;
  int _stalls = 0;

  bool get live => viewers > 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    error = null;
    code = await PairingCode.loadOrCreate();
    if (!_rendererReady) {
      await renderer.initialize();
      _rendererReady = true;
    }
    _notify();

    final ok = await ensureCamera();
    if (ok && !_readyFired) {
      _readyFired = true;
      onReady?.call();
    }
    if (!ok || !dbConfigured || started) return;

    started = true;
    _ice = await IceConfig.load(_db);
    await _safeDelete('cams/$code/sessions'); // drop stale offers
    _beatNow();
    _beat = Timer.periodic(kPresenceBeat, (_) => _beatNow());
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _pollSessions());
    _watch = Timer.periodic(const Duration(seconds: 10), (_) => _watchdog());
    _notify();
  }

  // ---- Camera -----------------------------------------------------------

  /// Opens camera + mic if not open yet (this is also what asks for permission).
  Future<bool> ensureCamera() {
    if (stream != null) return Future.value(true);
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<bool> _open() async {
    try {
      final s = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': facing,
          'width': {'ideal': kCaptureWidth},
          'height': {'ideal': kCaptureHeight},
          'frameRate': {'ideal': kCaptureFps},
        },
      }).timeout(const Duration(seconds: 25));
      stream = s;
      renderer.srcObject = s;
      error = null;
      _notify();
      return true;
    } catch (_) {
      error = 'Camera or microphone not available.';
      _notify();
      return false;
    }
  }

  Future<void> _closeCamera() async {
    final s = stream;
    if (s == null) return;
    stream = null;
    renderer.srcObject = null;
    for (final t in s.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await s.dispose();
    } catch (_) {}
    _notify();
  }

  /// Flip between the back and front camera (works while streaming).
  Future<void> switchFacing() async {
    final s = stream;
    if (s == null || s.getVideoTracks().isEmpty) return;
    try {
      await Helper.switchCamera(s.getVideoTracks().first);
      facing = facing == 'environment' ? 'user' : 'environment';
      for (final ch in _channels.values) {
        _sendFacing(ch);
      }
      _notify();
    } catch (_) {}
  }

  void _sendFacing(RTCDataChannel ch) {
    try {
      ch.send(RTCDataChannelMessage('facing:$facing'));
    } catch (_) {}
  }

  // ---- Self-healing -----------------------------------------------------

  /// If the camera silently freezes (it happens on some phones in the
  /// background), the encoder stops producing frames. Detect that and restart.
  Future<void> _watchdog() async {
    if (_disposed || _restarting || viewers == 0) {
      _lastFrames = -1;
      _stalls = 0;
      return;
    }
    int? frames;
    for (final e in _peers.entries) {
      if (!_connected.contains(e.key)) continue;
      frames = await _framesEncoded(e.value);
      if (frames != null) break;
    }
    if (frames == null) return;
    if (frames > _lastFrames) {
      _lastFrames = frames;
      _stalls = 0;
      return;
    }
    _stalls++;
    if (_stalls >= 2) {
      _stalls = 0;
      _lastFrames = -1;
      await _restartCamera();
    }
  }

  Future<int?> _framesEncoded(RTCPeerConnection pc) async {
    try {
      final reports = await pc.getStats();
      for (final r in reports) {
        if (r.type != 'outbound-rtp') continue;
        final kind = r.values['kind'] ?? r.values['mediaType'];
        if (kind != 'video') continue;
        final f = r.values['framesEncoded'];
        if (f is num) return f.toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _restartCamera() async {
    if (_restarting) return;
    _restarting = true;
    try {
      // Tell viewers to reconnect right away instead of waiting for a timeout.
      for (final ch in _channels.values) {
        try {
          ch.send(RTCDataChannelMessage('restart'));
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final sid in _peers.keys.toList()) {
        await _drop(sid);
      }
      await _closeCamera();
      await ensureCamera();
    } finally {
      _restarting = false;
    }
  }

  // ---- Signaling --------------------------------------------------------

  Future<void> _beatNow() async {
    try {
      await _db.put('cams/$code/presence', {
        'ts': {'.sv': 'timestamp'},
        'state': live ? 'live' : 'standby',
      });
    } catch (_) {}
  }

  Future<void> _safeDelete(String path) async {
    try {
      await _db.delete(path);
    } catch (_) {}
  }

  Future<void> _safePush(String path, Object data) async {
    try {
      await _db.push(path, data);
    } catch (_) {}
  }

  Future<void> _pollSessions() async {
    if (_polling || !started || _disposed || _restarting) return;
    _polling = true;
    try {
      final data = await _db.get('cams/$code/sessions');
      if (data is Map) {
        for (final e in data.entries) {
          final sid = e.key as String;
          final s = e.value;
          if (s is! Map) continue;

          if (!_peers.containsKey(sid) &&
              !_handled.contains(sid) &&
              s['offer'] is Map) {
            if (stream == null && !(await ensureCamera())) continue;
            _handled.add(sid);
            await _accept(sid, Map<String, dynamic>.from(s['offer'] as Map));
          }

          final pc = _peers[sid];
          final cands = s['viewerCandidates'];
          if (pc != null && cands is Map) {
            final seen = _seen.putIfAbsent(sid, () => <String>{});
            for (final ce in cands.entries) {
              final k = ce.key as String;
              if (seen.add(k) && ce.value is Map) {
                final c = ce.value as Map;
                try {
                  await pc.addCandidate(RTCIceCandidate(
                    c['candidate'] as String?,
                    c['sdpMid'] as String?,
                    c['sdpMLineIndex'] as int?,
                  ));
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {
      // network hiccup; next tick retries
    } finally {
      _polling = false;
    }
  }

  Future<void> _accept(String sid, Map<String, dynamic> offer) async {
    final s = stream;
    if (s == null) return;
    try {
      final pc = await createPeerConnection({
        'iceServers': _ice,
        'sdpSemantics': 'unified-plan',
      });
      _peers[sid] = pc;

      pc.onIceCandidate = (RTCIceCandidate c) {
        if (c.candidate == null) return;
        _safePush('cams/$code/sessions/$sid/cameraCandidates', {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      };

      // Control channel from the viewer (switch camera).
      pc.onDataChannel = (RTCDataChannel ch) {
        _channels[sid] = ch;
        ch.onMessage = (RTCDataChannelMessage m) {
          if (!m.isBinary && m.text == 'switch') switchFacing();
        };
        ch.onDataChannelState = (RTCDataChannelState st) {
          if (st == RTCDataChannelState.RTCDataChannelOpen) _sendFacing(ch);
        };
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _connected.add(sid);
            _syncViewers();
            Timer(const Duration(seconds: 6),
                () => _safeDelete('cams/$code/sessions/$sid'));
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            Timer(const Duration(seconds: 15), () {
              final cur = _peers[sid];
              if (cur != null &&
                  cur.connectionState !=
                      RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
                _drop(sid);
              }
            });
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _drop(sid);
            break;
          default:
            break;
        }
      };

      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?),
      );
      for (final t in s.getTracks()) {
        await pc.addTrack(t, s);
      }
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _db.put('cams/$code/sessions/$sid/answer', {
        'sdp': answer.sdp,
        'type': answer.type,
      });
    } catch (_) {
      await _drop(sid);
    }
  }

  void _syncViewers() {
    viewers = _connected.length;
    _notify();
    _beatNow();
  }

  Future<void> _drop(String sid) async {
    final pc = _peers.remove(sid);
    _channels.remove(sid);
    _connected.remove(sid);
    _seen.remove(sid);
    _syncViewers();
    _safeDelete('cams/$code/sessions/$sid');
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
      try {
        await pc.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _beat?.cancel();
    _watch?.cancel();
    for (final pc in _peers.values) {
      pc.close();
    }
    _peers.clear();
    stream?.getTracks().forEach((t) => t.stop());
    stream?.dispose();
    renderer.dispose();
    super.dispose();
  }
}
