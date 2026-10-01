import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';

/// Manages the camera's local media capture and its WebRTC peer connection.
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;

  Function(RTCIceCandidate candidate)? onIceCandidate;

  Future<MediaStream> getLocalStream({bool frontCamera = false}) async {
    final constraints = {
      'audio': true,
      'video': {
        'facingMode': frontCamera ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    };
    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    return localStream!;
  }

  Future<RTCPeerConnection> initPeerConnection() async {
    final config = {'iceServers': AppConfig.iceServers};
    _peerConnection = await createPeerConnection(config);

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, localStream!);
      }
    }

    _peerConnection!.onIceCandidate = (candidate) => onIceCandidate?.call(candidate);

    return _peerConnection!;
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteAnswer(RTCSessionDescription answer) async {
    await _peerConnection!.setRemoteDescription(answer);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> dispose() async {
    await localStream?.dispose();
    await _peerConnection?.close();
  }
}
