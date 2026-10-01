import 'package:firebase_core/firebase_core.dart';

/// DigiforgeDynamics CCTV — Firebase project config.
/// Signaling runs entirely through Firebase Realtime Database —
/// no separate signaling server needed.
class AppConfig {
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyDudBbfIHnLxTbthxIR9XSFiZ4QfNYHGvE',
    authDomain: 'digiforge-cctv-b9fee.firebaseapp.com',
    databaseURL: 'https://digiforge-cctv-b9fee-default-rtdb.firebaseio.com',
    projectId: 'digiforge-cctv-b9fee',
    storageBucket: 'digiforge-cctv-b9fee.firebasestorage.app',
    messagingSenderId: '378702996885',
    appId: '1:378702996885:web:1631521edd0665180e829c',
  );

  static const List<Map<String, dynamic>> iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  {
    'urls': 'turn:openrelay.metered.ca:80',
    'username': 'openrelayproject',
    'credential': 'openrelayproject',
  },
  {
    'urls': 'turn:openrelay.metered.ca:443',
    'username': 'openrelayproject',
    'credential': 'openrelayproject',
  },
  {
    'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
    'username': 'openrelayproject',
    'credential': 'openrelayproject',
  },
];
}
