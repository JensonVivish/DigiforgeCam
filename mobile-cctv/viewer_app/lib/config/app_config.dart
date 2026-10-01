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

  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': 'stun:stun.relay.metered.ca:80',
    },
    {
      'urls': 'turn:global.relay.metered.ca:80',
      'username': '16692b23a1916b00b4b9b0df',
      'credential': 'VXMVU4j9gG/LtumU',
    },
    {
      'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
      'username': '16692b23a1916b00b4b9b0df',
      'credential': 'VXMVU4j9gG/LtumU',
    },
    {
      'urls': 'turn:global.relay.metered.ca:443',
      'username': '16692b23a1916b00b4b9b0df',
      'credential': 'VXMVU4j9gG/LtumU',
    },
    {
      'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
      'username': '16692b23a1916b00b4b9b0df',
      'credential': 'VXMVU4j9gG/LtumU',
    },
  ];
}
