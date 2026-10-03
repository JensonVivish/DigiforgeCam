import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Helpers to convert WebRTC objects to/from plain maps for transport
/// over Socket.IO (which only carries JSON-serializable data).

Map<String, dynamic> iceCandidateToMap(RTCIceCandidate c) => {
      'candidate': c.candidate,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    };

RTCIceCandidate iceCandidateFromMap(Map<String, dynamic> m) => RTCIceCandidate(
      m['candidate'] as String?,
      m['sdpMid'] as String?,
      m['sdpMLineIndex'] as int?,
    );

Map<String, dynamic> sdpToMap(RTCSessionDescription sdp) => {
      'sdp': sdp.sdp,
      'type': sdp.type,
    };

RTCSessionDescription sdpFromMap(Map<String, dynamic> m) =>
    RTCSessionDescription(m['sdp'] as String?, m['type'] as String?);
