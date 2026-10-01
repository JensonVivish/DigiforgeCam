import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Camera-side signaling via Firebase Realtime Database.
///
/// Session structure in Firebase:
/// /sessions/{pairingCode}/
///   offer:      { sdp, type }
///   answer:     { sdp, type }
///   camera_ice: [ { candidate, sdpMid, sdpMLineIndex }, ... ]
///   viewer_ice: [ { candidate, sdpMid, sdpMLineIndex }, ... ]
///   status:     "waiting" | "viewer_joined" | "connected"

class SignalingService {
  final _db = FirebaseDatabase.instance;
  String? _pairingCode;
  DatabaseReference? _sessionRef;

  Function()? onViewerJoined;
  Function(Map<String, dynamic> data)? onSignal;
  Function()? onPeerDisconnected;

  /// Generates a random 6-character pairing code and writes
  /// a new session to Firebase. Returns the pairing code.
  Future<String> createSession() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    _pairingCode = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();

    _sessionRef = _db.ref('sessions/$_pairingCode');
    await _sessionRef!.set({
      'status': 'waiting',
      'created_at': ServerValue.timestamp,
    });

    // Watch for viewer joining (status changes to viewer_joined)
    _sessionRef!.child('status').onValue.listen((event) {
      final status = event.snapshot.value as String?;
      if (status == 'viewer_joined') {
        onViewerJoined?.call();
      } else if (status == 'disconnected') {
        onPeerDisconnected?.call();
      }
    });

    // Watch for answer from viewer
    _sessionRef!.child('answer').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      onSignal?.call({'kind': 'answer', 'payload': data});
    });

    // Watch for viewer ICE candidates
    _sessionRef!.child('viewer_ice').onChildAdded.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      onSignal?.call({'kind': 'ice-candidate', 'payload': data});
    });

    return _pairingCode!;
  }

  /// Writes the WebRTC offer to Firebase so the viewer can read it.
  Future<void> sendOffer(Map<String, dynamic> sdp) async {
    await _sessionRef!.child('offer').set(sdp);
  }

  /// Writes a camera-side ICE candidate to Firebase.
  Future<void> sendIceCandidate(Map<String, dynamic> candidate) async {
    await _sessionRef!.child('camera_ice').push().set(candidate);
  }

  Future<void> dispose() async {
    // Mark session as disconnected so viewer knows
    await _sessionRef?.child('status').set('disconnected');
    await _sessionRef?.remove();
  }
}
