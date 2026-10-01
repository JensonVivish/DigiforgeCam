import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate)? onIceCandidate;
  Function()? onConnectionFailed;

  Future<RTCPeerConnection> initPeerConnection() async {
    final config = {
      'iceServers': AppConfig.iceServers,
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) => onIceCandidate?.call(candidate);

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };

    // Detect and report connection failures
    _peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _peerConnection?.restartIce();
        onConnectionFailed?.call();
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
