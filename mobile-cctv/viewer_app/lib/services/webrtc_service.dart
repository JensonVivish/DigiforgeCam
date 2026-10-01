import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';

/// Manages the viewer's WebRTC peer connection and receives the camera's
/// remote media stream. The viewer sends no media of its own.
class WebRTCService {
  RTCPeerConnection? _peerConnection;

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate)? onIceCandidate;

  Future<RTCPeerConnection> initPeerConnection() async {
    final config = {'iceServers': AppConfig.iceServers};
    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) => onIceCandidate?.call(candidate);
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };

    return _peerConnection!;
  }

  Future<void> setRemoteOffer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> dispose() async {
    await _peerConnection?.close();
  }
}
