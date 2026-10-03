import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Owns the camera capture and one RTCPeerConnection per viewer attempt.
class CameraWebRTC {
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  List<Map<String, dynamic>> iceServers = const [];

  final List<RTCIceCandidate> _pending = [];
  bool _remoteStarted = false;
  bool _remoteReady = false;

  void Function(RTCIceCandidate candidate)? onIceCandidate;
  void Function(RTCIceConnectionState state)? onIceState;

  Future<MediaStream> openCamera({bool front = false}) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': front ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    });
    localStream = stream;
    return stream;
  }

  /// Closes any previous connection and builds a fresh one with the camera tracks.
  Future<void> newPeerConnection() async {
    await closeConnection();
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    pc.onIceCandidate = (candidate) {
      if (!identical(_pc, pc)) return;
      final text = candidate.candidate;
      if (text == null || text.isEmpty) return;
      onIceCandidate?.call(candidate);
    };
    pc.onIceConnectionState = (state) {
      if (!identical(_pc, pc)) return;
      onIceState?.call(state);
    };

    final stream = localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final pc = _pc;
    if (pc == null) throw StateError('No peer connection');
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteAnswer(RTCSessionDescription answer) async {
    final pc = _pc;
    if (pc == null || _remoteStarted) return;
    _remoteStarted = true;
    await pc.setRemoteDescription(answer);
    _remoteReady = true;
    await _flushPending(pc);
  }

  /// Candidates can arrive before the answer; queue them until it is applied.
  Future<void> addRemoteCandidate(RTCIceCandidate candidate) async {
    final pc = _pc;
    if (pc == null) return;
    if (!_remoteReady) {
      _pending.add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (_) {}
  }

  Future<void> _flushPending(RTCPeerConnection pc) async {
    final queued = List<RTCIceCandidate>.from(_pending);
    _pending.clear();
    for (final c in queued) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  Future<void> closeConnection() async {
    final old = _pc;
    _pc = null;
    _pending.clear();
    _remoteStarted = false;
    _remoteReady = false;
    try {
      await old?.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await closeConnection();
    try {
      await localStream?.dispose();
    } catch (_) {}
    localStream = null;
  }
}
