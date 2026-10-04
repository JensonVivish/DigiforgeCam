import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';
import 'runtime.dart';

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
      home: const CameraHome(),
    );
  }
}

class CameraHome extends StatefulWidget {
  const CameraHome({super.key});

  @override
  State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> with WidgetsBindingObserver {
  final ValueNotifier<int> _clipsRefresh = ValueNotifier<int>(0);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraService.onClipSaved = () => _clipsRefresh.value++;
    cameraService.setUiVisible(true);
    startRuntime(); // no-op if main() already started it
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    cameraService.setUiVisible(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraService.onClipSaved = null;
    cameraService.setUiVisible(false);
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
          CameraScreen(svc: cameraService, bg: backgroundController),
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
