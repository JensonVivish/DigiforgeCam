import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'screens/streaming_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: AppConfig.firebaseOptions);
  await [Permission.camera, Permission.microphone].request();
  runApp(const DigiforgeCctvCameraApp());
}

class DigiforgeCctvCameraApp extends StatelessWidget {
  const DigiforgeCctvCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digiforge CCTV Camera',
      debugShowCheckedModeBanner: false,
      theme: DigiforgeBrand.theme(),
      home: const StreamingScreen(),
    );
  }
}
