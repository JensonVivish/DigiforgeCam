import 'package:firebase_core/firebase_core.dart';

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

  /// Free public STUN servers only. TURN relay servers (needed on some mobile
  /// networks) are loaded at runtime from Firebase at `config/ice_servers`,
  /// so no relay credentials ever live in the source code or the GitHub repo.
  static const List<Map<String, dynamic>> fallbackIceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']
    },
    {
      'urls': ['stun:stun.cloudflare.com:3478']
    },
  ];
}
