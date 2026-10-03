import 'dart:async';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Runs the camera side: captures video+audio, publishes presence, answers
/// viewer offers through Firebase RTDB signaling, then streams peer-to-peer.
class CameraService extends ChangeNotifier {
  final Rtdb _db = Rtdb();
  final RTCVideoRenderer renderer = RTCVideoRenderer();

  String code = '------';
  MediaStream? stream;
  String? error;
  int viewers = 0;
  bool recording = false;
  Duration recElapsed = Duration.zero;
  VoidCallback? onClipSaved;

  final Map<String, RTCPeerConnection> _peers = {};
  final Set<String> _handled = {};
  final Set<String> _connected = {};
  final Map<String, Set<String>> _seen = {};
  List<Map<String, dynamic>> _ice = [];

  Timer? _poll;
  Timer? _beat;
  Timer? _recTimer;
  bool _polling = false;
  bool _rendererReady = false;
  bool _disposed = false;
  MediaRecorder? _recorder;

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

    if (stream == null) {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'environment',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
            'frameRate': {'ideal': 24},
          },
        });
        renderer.srcObject = stream;
      } catch (e) {
        error = 'Camera or microphone unavailable. Grant permission and try again.';
      }
    }
    _notify();
    if (stream == null || !dbConfigured) return;

    _ice = await IceConfig.load(_db);
    await _safeDelete('cams/$code/sessions'); // drop stale offers
    _poll?.cancel();
    _beat?.cancel();
    _beatNow();
    _beat = Timer.periodic(kPresenceBeat, (_) => _beatNow());
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _pollSessions());
  }

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
    if (_polling || stream == null || _disposed) return;
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

      pc.onConnectionState = (RTCPeerConnectionState state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _connected.add(sid);
            _syncViewers();
            // Handshake is done; tidy the signaling node shortly after.
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

  // ---- Recording --------------------------------------------------------

  Future<void> toggleRecording() => recording ? stopRecording() : startRecording();

  Future<void> startRecording() async {
    final s = stream;
    if (s == null || s.getVideoTracks().isEmpty || recording) return;
    try {
      final path = await ClipsStore.newPath('camera');
      final rec = MediaRecorder();
      await rec.start(
        path,
        videoTrack: s.getVideoTracks().first,
        audioChannel: RecorderAudioChannel.INPUT,
      );
      _recorder = rec;
      recording = true;
      recElapsed = Duration.zero;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recElapsed += const Duration(seconds: 1);
        _notify();
      });
    } catch (e) {
      error = 'Could not start recording: $e';
    }
    _notify();
  }

  Future<void> stopRecording() async {
    _recTimer?.cancel();
    final rec = _recorder;
    _recorder = null;
    recording = false;
    try {
      await rec?.stop();
    } catch (e) {
      error = 'Could not finish recording: $e';
    }
    onClipSaved?.call();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _beat?.cancel();
    _recTimer?.cancel();
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
