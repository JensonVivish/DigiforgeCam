import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Owns one RTCPeerConnection per connection attempt and receives the
/// camera's stream. The viewer sends no media of its own.
class ViewerWebRTC {
  RTCPeerConnection? _pc;
  List<Map<String, dynamic>> iceServers = const [];

  final List<RTCIceCandidate> _pending = [];
  bool _remoteStarted = false;
  bool _remoteReady = false;
  MediaStream? _fallbackStream;

  void Function(MediaStream stream)? onRemoteStream;
  void Function(RTCIceCandidate candidate)? onIceCandidate;
  void Function(RTCIceConnectionState state)? onIceState;

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
    pc.onTrack = (event) async {
      if (!identical(_pc, pc)) return;
      MediaStream? stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams.first;
      } else {
        // Some devices deliver tracks without a stream: build one ourselves.
        _fallbackStream ??= await createLocalMediaStream(
            'remote_${DateTime.now().millisecondsSinceEpoch}');
        await _fallbackStream!.addTrack(event.track);
        stream = _fallbackStream;
      }
      if (stream != null) onRemoteStream?.call(stream);
    };
  }

  Future<void> setRemoteOffer(RTCSessionDescription offer) async {
    final pc = _pc;
    if (pc == null || _remoteStarted) return;
    _remoteStarted = true;
    await pc.setRemoteDescription(offer);
    _remoteReady = true;
    final queued = List<RTCIceCandidate>.from(_pending);
    _pending.clear();
    for (final c in queued) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    final pc = _pc;
    if (pc == null) throw StateError('No peer connection');
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer;
  }

  /// Candidates can arrive before the offer; queue them until it is applied.
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

  Future<void> closeConnection() async {
    final old = _pc;
    _pc = null;
    _pending.clear();
    _remoteStarted = false;
    _remoteReady = false;
    _fallbackStream = null;
    try {
      await old?.close();
    } catch (_) {}
  }

  Future<void> dispose() => closeConnection();
}
