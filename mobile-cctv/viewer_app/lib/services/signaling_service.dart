import 'package:firebase_database/firebase_database.dart';

/// Viewer-side signaling via Firebase Realtime Database.
/// Joins an existing session by pairing code, reads the camera's
/// offer, writes back the answer and ICE candidates.

class SignalingService {
  final _db = FirebaseDatabase.instance;
  String? _pairingCode;
  DatabaseReference? _sessionRef;

  Function(Map<String, dynamic> data)? onSignal;
  Function()? onPeerDisconnected;
  Function(String message)? onError;

  Future<void> joinSession(String pairingCode) async {
    _pairingCode = pairingCode;
    _sessionRef = _db.ref('sessions/$pairingCode');

    // Check session exists
    final snapshot = await _sessionRef!.get();
    if (!snapshot.exists) {
      onError?.call('Invalid or expired pairing code');
      return;
    }

    // Mark viewer as joined
    await _sessionRef!.child('status').set('viewer_joined');

    // Watch for camera's offer
    _sessionRef!.child('offer').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      onSignal?.call({'kind': 'offer', 'payload': data});
    });

    // Watch for camera ICE candidates
    _sessionRef!.child('camera_ice').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      onSignal?.call({'kind': 'ice-candidate', 'payload': data});
    });

    // Watch for disconnection
    _sessionRef!.child('status').onValue.listen((event) {
      final status = event.snapshot.value as String?;
      if (status == 'disconnected') onPeerDisconnected?.call();
    });
  }

  /// Writes the WebRTC answer to Firebase so the camera can read it.
  Future<void> sendAnswer(Map<String, dynamic> sdp) async {
    await _sessionRef!.child('answer').set(sdp);
    await _sessionRef!.child('status').set('connected');
  }

  /// Writes a viewer-side ICE candidate to Firebase.
  Future<void> sendIceCandidate(Map<String, dynamic> candidate) async {
    await _sessionRef!.child('viewer_ice').push().set(candidate);
  }

  Future<void> dispose() async {
    await _sessionRef?.child('status').set('disconnected');
  }
}
