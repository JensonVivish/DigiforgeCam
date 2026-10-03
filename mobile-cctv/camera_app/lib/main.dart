import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camera_screen.dart';
import 'camera_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiForge Camera',
      debugShowCheckedModeBanner: false,
      theme: dfTheme(),
      home: const CameraHome(),
    );
  }
}

class CameraHome extends StatefulWidget {
  const CameraHome({super.key});

  @override
  State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> {
  final CameraService _svc = CameraService();
  final ValueNotifier<int> _clipsRefresh = ValueNotifier<int>(0);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the camera phone awake
    _svc.onClipSaved = () => _clipsRefresh.value++;
    _svc.start();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _svc.dispose();
    _clipsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const BrandTitle('CAMERA'),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          CameraScreen(svc: _svc),
          ClipsScreen(
            title: 'Recordings',
            emptyHint: 'No recordings yet.\nStart a recording from the Camera tab.',
            refresh: _clipsRefresh,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _clipsRefresh.value++;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Recordings',
          ),
        ],
      ),
    );
  }
}
