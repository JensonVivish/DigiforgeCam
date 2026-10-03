import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Viewer-side signaling over Firebase Realtime Database (see camera side for
/// the data layout). Each connection try gets a fresh attemptId.
class ViewerSignaling {
  ViewerSignaling(this.code);

  final String code;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final DatabaseReference _session = _db.ref('sessions/$code');

  StreamSubscription<DatabaseEvent>? _offerSub;
  StreamSubscription<DatabaseEvent>? _iceSub;
  StreamSubscription<DatabaseEvent>? _onlineSub;
  String? _attemptId;

  void Function(Map<String, dynamic> sdp)? onOffer;
  void Function(Map<String, dynamic> candidate)? onCameraIce;
  void Function(bool online)? onCameraOnline;

  /// true = a camera registered this code, false = no such code.
  /// Throws if Firebase can't be reached.
  Future<bool> sessionExists() async {
    final snap =
        await _session.child('created_at').get().timeout(const Duration(seconds: 10));
    return snap.exists;
  }

  void watchCameraOnline() {
    _onlineSub?.cancel();
    _onlineSub = _session.child('camera_online').onValue.listen((event) {
      onCameraOnline?.call(event.snapshot.value == true);
    });
  }

  /// Stops listening to the current attempt (call before building a new connection).
  void endAttempt() {
    _offerSub?.cancel();
    _iceSub?.cancel();
    _offerSub = null;
    _iceSub = null;
  }

  /// Starts a new attempt: listens for the camera's offer/candidates, then
  /// asks the camera to connect.
  void beginAttempt() {
    final old = _attemptId;
    endAttempt();
    final id = _randomId();
    _attemptId = id;
    final rtc = _session.child('rtc/$id');

    _offerSub = rtc.child('offer').onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is Map) onOffer?.call(Map<String, dynamic>.from(v));
    });
    _iceSub = rtc.child('camera_ice').onChildAdded.listen((event) {
      final v = event.snapshot.value;
      if (v is Map) onCameraIce?.call(Map<String, dynamic>.from(v));
    });

    _fire(_session.child('viewer_request').set({
      'id': id,
      'at': ServerValue.timestamp,
    }));
    if (old != null) _fire(_session.child('rtc/$old').remove());
  }

  void sendAnswer(Map<String, dynamic> sdp) {
    final id = _attemptId;
    if (id == null) return;
    _fire(_session.child('rtc/$id/answer').set(sdp));
  }

  void sendIceCandidate(Map<String, dynamic> candidate) {
    final id = _attemptId;
    if (id == null) return;
    _fire(_session.child('rtc/$id/viewer_ice').push().set(candidate));
  }

  void dispose() {
    endAttempt();
    _onlineSub?.cancel();
    final id = _attemptId;
    if (id != null) _fire(_session.child('rtc/$id').remove());
  }

  static String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static void _fire(Future<void> f) {
    f.catchError((_) {});
  }
}
