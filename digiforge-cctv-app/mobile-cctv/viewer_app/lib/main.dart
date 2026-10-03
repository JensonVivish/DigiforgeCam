import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: AppConfig.firebaseOptions);
  runApp(const DigiforgeCctvViewerApp());
}

class DigiforgeCctvViewerApp extends StatelessWidget {
  const DigiforgeCctvViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digiforge CCTV Viewer',
      debugShowCheckedModeBanner: false,
      theme: DigiforgeBrand.theme(),
      home: const HomeScreen(),
    );
  }
}
