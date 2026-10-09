import 'dart:async';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Modest capture settings: friendly to older phones, battery and mobile upload.
const int kCaptureWidth = 640;
const int kCaptureHeight = 480;
const int kCaptureFps = 15;

/// Camera side. It sits idle (camera and microphone OFF) and publishes a
/// heartbeat. When a viewer presses Turn on, it opens the camera, answers the
/// viewer through Firebase signaling and streams peer-to-peer. When the last
/// viewer leaves, the camera and mic are switched off again.
/// Started from main(), not from a widget, so it also runs with no screen.
class CameraService extends ChangeNotifier {
  final Rtdb _db = Rtdb();

  String code = '------';
  MediaStream? stream;
  String? error; // internal only; never shown once setup is finished
  String facing = 'environment'; // 'environment' = back, 'user' = front
  String deviceName = 'Camera';
  VoidCallback? onReady; // fired once, when signaling is ready
  bool _readyFired = false;
  bool started = false;
  bool accessGranted = false;
  DateTime _lastActive = DateTime.now();

  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCDataChannel> _channels = {};
  final Set<String> _handled = {};
  final Set<String> _connected = {};
  final Map<String, Set<String>> _seen = {};
  List<Map<String, dynamic>> _ice = [];
  String _lastCmdId = '';

  Timer? _poll;
  Timer? _beat;
  Timer? _watch;
  bool _polling = false;
  bool _disposed = false;
  bool _restarting = false;
  bool _switching = false;
  Future<bool>? _opening;
  int _lastFrames = -1;
  int _stalls = 0;

  int get viewers => _connected.length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDeviceName(String manufacturer, String model) {
    final m = manufacturer.isEmpty
        ? ''
        : manufacturer[0].toUpperCase() + manufacturer.substring(1);
    final base = ('$m $model').trim();
    deviceName = base.isEmpty ? 'Camera' : base;
  }

  Future<void> start() async {
    code = await PairingCode.loadOrCreate();
    _notify();

    if (!_readyFired) {
      _readyFired = true;
      onReady?.call(); // lets the foreground service start
    }
    if (!dbConfigured || started) return;

    started = true;
    _ice = await IceConfig.load(_db);
    await _safeDelete('cams/$code/sessions'); // drop stale offers
    try {
      final c = await _db.get('cams/$code/cmd'); // ignore commands from before this start
      _lastCmdId = (c is Map ? c['id']?.toString() : null) ?? '';
    } catch (_) {}
    _beatNow();
    _beat = Timer.periodic(kPresenceBeat, (_) {
      _beatNow();
      _maybeSleep();
    });
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollSessions());
    _watch = Timer.periodic(const Duration(seconds: 5), (_) => _watchdog());
    _notify();
  }

  // ---- Camera on / off --------------------------------------------------

  /// Opens camera + mic if not open yet.
  Future<bool> ensureCamera() {
    if (stream != null) return Future.value(true);
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Map<String, dynamic> _video(String f) => {
        'facingMode': f,
        'width': {'ideal': kCaptureWidth},
        'height': {'ideal': kCaptureHeight},
        'frameRate': {'ideal': kCaptureFps},
      };

  /// Tries the preferred settings first, then simpler ones (other lens, video
  /// only if the microphone is busy), and retries once after a short pause
  /// because a camera that was just released by another app needs a moment.
  Future<bool> _open() async {
    final other = facing == 'user' ? 'environment' : 'user';
    final attempts = <List<Object>>[
      [{'audio': true, 'video': _video(facing)}, facing],
      [{'audio': true, 'video': {'facingMode': facing}}, facing],
      [{'audio': true, 'video': {'facingMode': other}}, other],
      [{'audio': false, 'video': {'facingMode': facing}}, facing],
      [{'audio': false, 'video': true}, facing],
    ];
    var lastErr = '';
    for (var round = 0; round < 2; round++) {
      for (final a in attempts) {
        try {
          final s = await navigator.mediaDevices
              .getUserMedia(a[0] as Map<String, dynamic>)
              .timeout(const Duration(seconds: 12));
          stream = s;
          facing = a[1] as String;
          accessGranted = true;
          error = null;
          _lastActive = DateTime.now();
          _notify();
          _diag('camera is on');
          return true;
        } on TimeoutException {
          error = 'Camera did not respond.';
          _diag('camera did not respond in time');
          _notify();
          return false;
        } catch (e) {
          lastErr = e.toString(); // try the next, simpler variant
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    error = 'Camera or microphone not available.';
    final short = lastErr.length > 140 ? lastErr.substring(0, 140) : lastErr;
    _diag('camera could not open: $short');
    _notify();
    return false;
  }

  Future<void> _closeCamera() async {
    final s = stream;
    if (s == null) return;
    stream = null;
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

  /// Turn the camera and mic off when nobody is watching any more.
  void _maybeSleep() {
    if (stream == null || _restarting || _switching) return;
    if (_peers.isNotEmpty || viewers > 0) {
      _lastActive = DateTime.now();
      return;
    }
    if (DateTime.now().difference(_lastActive) >= const Duration(seconds: 15)) {
      _closeCamera();
    }
  }

  // ---- Front / back camera ----------------------------------------------

  /// Switch to the 'user' (front) or 'environment' (back) camera. The target
  /// is explicit, so repeating or duplicating a command changes nothing.
  Future<void> setFacing(String want) async {
    if (want != 'user' && want != 'environment') return;
    if (_switching) return;
    if (want == facing) {
      _broadcastFacing();
      _beatNow();
      return;
    }
    final s = stream;
    if (s == null || s.getVideoTracks().isEmpty) {
      facing = want; // used the next time the camera turns on
      _broadcastFacing();
      _beatNow();
      return;
    }
    _switching = true;
    var switched = false;
    try {
      await Helper.switchCamera(s.getVideoTracks().first);
      switched = true;
    } catch (_) {}
    facing = want;
    if (!switched) {
      // Plan B: reopen the camera on the requested lens; viewers reconnect by themselves.
      await _restartCamera();
    }
    _switching = false;
    _lastActive = DateTime.now();
    _broadcastFacing();
    _beatNow();
  }

  void _broadcastFacing() {
    for (final ch in _channels.values) {
      _sendFacing(ch);
    }
  }

  void _sendFacing(RTCDataChannel ch) {
    try {
      ch.send(RTCDataChannelMessage('facing:$facing'));
    } catch (_) {}
  }

  // ---- Self-healing -----------------------------------------------------

  /// If the camera silently freezes (or another app takes it), the encoder
  /// stops producing frames. Detect that and restart the camera.
  Future<void> _watchdog() async {
    if (_disposed || _restarting || _switching) return;
    if (stream == null) return; // off on purpose until a viewer turns it on
    if (viewers == 0) {
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
      final suffix = code.length >= 3 ? code.substring(code.length - 3) : code;
      await _db.put('cams/$code/presence', {
        'ts': {'.sv': 'timestamp'},
        'state': viewers > 0 ? 'live' : 'standby',
        'name': '$deviceName ($suffix)',
        'facing': facing,
      });
    } catch (_) {}
  }

  /// Latest step, written to Firebase so the viewer can show why a connection
  /// is slow or failing.
  void _diag(String msg) {
    if (!started) return;
    _db.put('cams/$code/diag', {
      'ts': {'.sv': 'timestamp'},
      'msg': msg,
    }).catchError((_) {});
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
      final all = await _db.get('cams/$code');
      if (all is Map) {
        // Camera switch command from the viewer (backup path to the data channel).
        final cmd = all['cmd'];
        if (cmd is Map && cmd['id'] != null && cmd['id'].toString() != _lastCmdId) {
          _lastCmdId = cmd['id'].toString();
          final f = cmd['facing'];
          if (f is String) setFacing(f);
        }

        final data = all['sessions'];
        if (data is Map) {
          for (final e in data.entries) {
            final sid = e.key as String;
            final s = e.value;
            if (s is! Map) continue;

            if (!_peers.containsKey(sid) &&
                !_handled.contains(sid) &&
                s['offer'] is Map) {
              _handled.add(sid);
              _diag('request received, turning camera on');
              // A viewer wants in: turn the camera on first.
              if (stream == null && !(await ensureCamera())) continue;
              // The viewer may have given up while the camera was starting.
              final fresh = await _db.get('cams/$code/sessions/$sid/offer');
              if (fresh is! Map) continue;
              _lastActive = DateTime.now();
              await _accept(sid, Map<String, dynamic>.from(fresh));
              _diag('answer sent, connecting');
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

      // Control channel from the viewer (front/back camera).
      pc.onDataChannel = (RTCDataChannel ch) {
        _channels[sid] = ch;
        ch.onMessage = (RTCDataChannelMessage m) {
          if (m.isBinary) return;
          final t = m.text;
          if (t.startsWith('set:')) setFacing(t.substring(4));
        };
        ch.onDataChannelState = (RTCDataChannelState st) {
          if (st == RTCDataChannelState.RTCDataChannelOpen) _sendFacing(ch);
        };
      };

      pc.onConnectionState = (RTCPeerConnectionState state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _connected.add(sid);
            _diag('connected');
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
            _diag('network connection failed (strict network?)');
            _drop(sid);
            break;
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
    } catch (e) {
      _diag('could not answer: $e');
      await _drop(sid);
    }
  }

  void _syncViewers() {
    if (viewers > 0) _lastActive = DateTime.now();
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
    super.dispose();
  }
}
