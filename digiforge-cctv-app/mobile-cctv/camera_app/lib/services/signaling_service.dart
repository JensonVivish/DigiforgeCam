import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Camera-side signaling over Firebase Realtime Database.
///
/// sessions/{code}/
///   created_at, camera_online
///   viewer_request : { id, at }      <- a viewer asks for a (new) connection
///   rtc/{attemptId}/
///     offer, answer
///     camera_ice/{pushId}, viewer_ice/{pushId}
///
/// Every connection try by the viewer uses a fresh attemptId, so stale
/// offers/answers/candidates from earlier tries can never be mixed in.
class CameraSignaling {
  CameraSignaling(this.code);

  final String code;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final DatabaseReference _session = _db.ref('sessions/$code');

  StreamSubscription<DatabaseEvent>? _connSub;
  StreamSubscription<DatabaseEvent>? _requestSub;
  StreamSubscription<DatabaseEvent>? _answerSub;
  StreamSubscription<DatabaseEvent>? _iceSub;

  String? _lastRequestId;
  String? _attemptId;

  void Function(String attemptId)? onViewerRequest;
  void Function(Map<String, dynamic> sdp)? onAnswer;
  void Function(Map<String, dynamic> candidate)? onViewerIce;
  void Function(bool connected)? onFirebaseConnection;

  /// Starts listening. Never blocks, so the camera also starts while offline.
  void start() {
    _fire(_session.child('rtc').remove());
    _fire(_session.child('viewer_request').remove());
    _fire(_session.child('created_at').set(ServerValue.timestamp));

    // Presence: re-armed every time Firebase (re)connects.
    _connSub = _db.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value == true;
      onFirebaseConnection?.call(connected);
      if (connected) {
        final online = _session.child('camera_online');
        _fire(online.onDisconnect().set(false));
        _fire(online.set(true));
      }
    });

    _requestSub = _session.child('viewer_request').onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is! Map) return;
      final id = v['id'];
      if (id is! String || id == _lastRequestId) return;
      _lastRequestId = id;
      onViewerRequest?.call(id);
    });
  }

  /// Switches to a new viewer attempt: drops the old one and listens for the
  /// answer and the viewer's ICE candidates of the new one.
  void beginAttempt(String id) {
    final old = _attemptId;
    _attemptId = id;
    _answerSub?.cancel();
    _iceSub?.cancel();
    if (old != null && old != id) {
      _fire(_session.child('rtc/$old').remove());
    }
    final rtc = _session.child('rtc/$id');
    _answerSub = rtc.child('answer').onValue.listen((event) {
      final v = event.snapshot.value;
      if (v is Map) onAnswer?.call(Map<String, dynamic>.from(v));
    });
    _iceSub = rtc.child('viewer_ice').onChildAdded.listen((event) {
      final v = event.snapshot.value;
      if (v is Map) onViewerIce?.call(Map<String, dynamic>.from(v));
    });
  }

  void sendOffer(Map<String, dynamic> sdp) {
    final id = _attemptId;
    if (id == null) return;
    _fire(_session.child('rtc/$id/offer').set(sdp));
  }

  void sendCameraIce(Map<String, dynamic> candidate) {
    final id = _attemptId;
    if (id == null) return;
    _fire(_session.child('rtc/$id/camera_ice').push().set(candidate));
  }

  void stop() {
    _connSub?.cancel();
    _requestSub?.cancel();
    _answerSub?.cancel();
    _iceSub?.cancel();
    _fire(_session.child('camera_online').set(false));
  }

  /// Removes the whole session (used when the pairing code is reset).
  void deleteSession() {
    stop();
    _fire(_session.remove());
  }

  static void _fire(Future<void> f) {
    f.catchError((_) {});
  }
}
