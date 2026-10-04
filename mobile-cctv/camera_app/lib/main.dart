import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';
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
      home: const SetupGate(child: _Home()),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 64, title: const BrandTitle('CAMERA')),
      body: CameraScreen(svc: cameraService, bg: backgroundController),
    );
  }
}
