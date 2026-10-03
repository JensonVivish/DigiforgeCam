import 'dart:async';
import 'dart:math';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ViewerState { idle, connecting, live, reconnecting }

/// Viewer side: offers to the camera through Firebase RTDB signaling, then
/// receives the stream peer-to-peer. Reconnects forever with capped backoff.
class ViewerService extends ChangeNotifier {
  final Rtdb _db = Rtdb();
  final RTCVideoRenderer renderer = RTCVideoRenderer();

  String? lastCode; // last paired camera (one-tap reconnect)
  String? target; // camera we are currently trying to watch
  ViewerState state = ViewerState.idle;
  bool? cameraOnline; // null = still checking
  int retryIn = 0;
  int attempt = 0;
  bool recording = false;
  Duration recElapsed = Duration.zero;
  String? error;
  VoidCallback? onClipSaved;

  RTCPeerConnection? _pc;
  MediaStream? _remote;
  String? _sid;
  String? _cam;
  int _gen = 0;
  bool _want = false;
  bool _answered = false;
  bool _pollBusy = false;
  bool _disposed = false;
  final Set<String> _seen = {};

  Timer? _answerTimer;
  Timer? _deadline;
  Timer? _retryTimer;
  Timer? _presenceTimer;
  Timer? _recTimer;
  MediaRecorder? _recorder;

  String? _lastTs;
  DateTime _lastTsChange = DateTime.now();
  bool _tsSeenChange = false;

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    await renderer.initialize();
    lastCode = await PairingCode.loadLast();
    _n();
  }

  // ---- Public controls --------------------------------------------------

  Future<void> connect(String code) async {
    error = null;
    _want = true;
    target = code;
    attempt = 0;
    cameraOnline = null;
    _lastTs = null;
    _tsSeenChange = false;
    lastCode = code;
    await PairingCode.saveLast(code);
    _startPresenceWatch();
    await _connect();
  }

  Future<void> disconnect() async {
    _want = false;
    _gen++;
    _retryTimer?.cancel();
    _presenceTimer?.cancel();
    _cancelPeerTimers();
    await _teardownPeer();
    state = ViewerState.idle;
    target = null;
    cameraOnline = null;
    retryIn = 0;
    _n();
  }

  Future<void> forgetLast() async {
    await PairingCode.forgetLast();
    lastCode = null;
    _n();
  }

  // ---- Connection -------------------------------------------------------

  Future<void> _connect() async {
    final cam = target;
    if (!_want || cam == null) return;
    final gen = ++_gen;
    await _teardownPeer();
    if (gen != _gen) return;

    state = attempt == 0 ? ViewerState.connecting : ViewerState.reconnecting;
    retryIn = 0;
    _n();

    try {
      final ice = await IceConfig.load(_db);
      if (gen != _gen) return;

      final sid = _randomId();
      _sid = sid;
      _cam = cam;
      _answered = false;
      _seen.clear();

      final pc = await createPeerConnection({
        'iceServers': ice,
        'sdpSemantics': 'unified-plan',
      });
      if (gen != _gen) {
        await pc.close();
        return;
      }
      _pc = pc;

      pc.onTrack = (RTCTrackEvent e) {
        if (gen != _gen) return;
        if (e.streams.isNotEmpty) {
          _remote = e.streams.first;
          renderer.srcObject = _remote;
          _n();
        }
      };
      pc.onIceCandidate = (RTCIceCandidate c) {
        if (gen != _gen || c.candidate == null) return;
        _safePush('cams/$cam/sessions/$sid/viewerCandidates', {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      };
      pc.onConnectionState = (RTCPeerConnectionState s) => _onConn(gen, s);

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _db.put('cams/$cam/sessions/$sid/offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      if (gen != _gen) return;

      _answerTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _pollAnswer(gen));
      _deadline = Timer(const Duration(seconds: 25), () {
        if (gen == _gen && state != ViewerState.live) _scheduleRetry();
      });
    } catch (_) {
      if (gen == _gen) _scheduleRetry();
    }
  }

  void _onConn(int gen, RTCPeerConnectionState s) {
    if (gen != _gen) return;
    switch (s) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        attempt = 0;
        _answerTimer?.cancel();
        _deadline?.cancel();
        state = ViewerState.live;
        _n();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        state = ViewerState.reconnecting;
        _n();
        Timer(const Duration(seconds: 6), () {
          if (gen == _gen &&
              _pc?.connectionState !=
                  RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _scheduleRetry();
          }
        });
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _scheduleRetry();
        break;
      default:
        break;
    }
  }

  Future<void> _pollAnswer(int gen) async {
    if (_pollBusy || gen != _gen) return;
    _pollBusy = true;
    try {
      final pc = _pc;
      final cam = _cam;
      final sid = _sid;
      if (pc == null || cam == null || sid == null) return;
      final s = await _db.get('cams/$cam/sessions/$sid');
      if (gen != _gen || s is! Map) return;

      if (!_answered && s['answer'] is Map) {
        final a = s['answer'] as Map;
        await pc.setRemoteDescription(
          RTCSessionDescription(a['sdp'] as String?, a['type'] as String?),
        );
        _answered = true;
      }

      final cands = s['cameraCandidates'];
      if (_answered && cands is Map) {
        for (final ce in cands.entries) {
          final k = ce.key as String;
          if (_seen.add(k) && ce.value is Map) {
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
    } catch (_) {
      // transient network error; next tick retries
    } finally {
      _pollBusy = false;
    }
  }

  /// Never gives up: 1s, 2s, 4s, 8s, then every 15s.
  void _scheduleRetry() {
    if (!_want) return;
    _gen++;
    _cancelPeerTimers();
    _teardownPeer();
    attempt++;
    const steps = [1, 2, 4, 8, 15];
    retryIn = steps[min(attempt - 1, steps.length - 1)];
    state = ViewerState.reconnecting;
    _n();
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      retryIn--;
      if (retryIn <= 0) {
        t.cancel();
        _connect();
      } else {
        _n();
      }
    });
  }

  void _cancelPeerTimers() {
    _answerTimer?.cancel();
    _deadline?.cancel();
  }

  Future<void> _teardownPeer() async {
    if (recording) await stopRecording();
    final pc = _pc;
    final cam = _cam;
    final sid = _sid;
    _pc = null;
    _sid = null;
    _cam = null;
    _remote = null;
    renderer.srcObject = null;
    if (cam != null && sid != null) _safeDelete('cams/$cam/sessions/$sid');
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
      try {
        await pc.dispose();
      } catch (_) {}
    }
  }

  // ---- Camera presence --------------------------------------------------

  void _startPresenceWatch() {
    _presenceTimer?.cancel();
    _checkPresence();
    _presenceTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkPresence());
  }

  /// Clock-skew-proof: we only look at whether the camera's server timestamp
  /// keeps changing, never at our own clock vs. theirs.
  Future<void> _checkPresence() async {
    final cam = target;
    if (cam == null) return;
    try {
      final v = await _db.get('cams/$cam/presence/ts');
      final ts = v?.toString();
      final now = DateTime.now();
      bool? online;
      if (ts == null) {
        online = false;
      } else if (_lastTs == null) {
        _lastTs = ts;
        _lastTsChange = now;
        _tsSeenChange = false;
        online = null;
      } else if (ts != _lastTs) {
        _lastTs = ts;
        _lastTsChange = now;
        _tsSeenChange = true;
        online = true;
      } else if (now.difference(_lastTsChange) > const Duration(seconds: 12)) {
        online = false;
      } else {
        online = _tsSeenChange ? true : null;
      }

      final cameBack = online == true && cameraOnline != true;
      if (online != cameraOnline) {
        cameraOnline = online;
        _n();
      }
      // Camera just reappeared: don't wait out the backoff timer.
      if (cameBack && _want && state == ViewerState.reconnecting && retryIn > 0) {
        _retryTimer?.cancel();
        attempt = 0;
        _connect();
      }
    } catch (_) {}
  }

  // ---- Recording --------------------------------------------------------

  Future<void> toggleRecording() => recording ? stopRecording() : startRecording();

  Future<void> startRecording() async {
    final r = _remote;
    if (r == null ||
        r.getVideoTracks().isEmpty ||
        recording ||
        state != ViewerState.live) {
      return;
    }
    try {
      final path = await ClipsStore.newPath('viewer');
      final rec = MediaRecorder();
      await rec.start(
        path,
        videoTrack: r.getVideoTracks().first,
        audioChannel: RecorderAudioChannel.OUTPUT,
      );
      _recorder = rec;
      recording = true;
      recElapsed = Duration.zero;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recElapsed += const Duration(seconds: 1);
        _n();
      });
    } catch (e) {
      error = 'Could not start recording: $e';
    }
    _n();
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
    _n();
  }

  // ---- Helpers ----------------------------------------------------------

  String _randomId() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
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

  @override
  void dispose() {
    _disposed = true;
    _want = false;
    _gen++;
    _retryTimer?.cancel();
    _presenceTimer?.cancel();
    _recTimer?.cancel();
    _cancelPeerTimers();
    _pc?.close();
    renderer.dispose();
    super.dispose();
  }
}
