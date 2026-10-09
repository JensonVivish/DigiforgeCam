import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'runtime.dart';
import 'setup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CameraApp());
  // Not tied to any widget: this also runs when started headless (after boot).
  startRuntime();
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiForge Camera',
      debugShowCheckedModeBanner: false,
      theme: dfTheme(),
      home: const SetupGate(),
    );
  }
}
