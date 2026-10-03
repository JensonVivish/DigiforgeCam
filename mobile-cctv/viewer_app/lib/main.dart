import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_screen.dart';
import 'viewer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ViewerApp());
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiForge Viewer',
      debugShowCheckedModeBanner: false,
      theme: dfTheme(),
      home: const ViewerHome(),
    );
  }
}

class ViewerHome extends StatefulWidget {
  const ViewerHome({super.key});

  @override
  State<ViewerHome> createState() => _ViewerHomeState();
}

class _ViewerHomeState extends State<ViewerHome> {
  final ViewerService _svc = ViewerService();
  final ValueNotifier<int> _clipsRefresh = ValueNotifier<int>(0);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _svc.onClipSaved = () => _clipsRefresh.value++;
    _svc.init();
  }

  @override
  void dispose() {
    _svc.dispose();
    _clipsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const BrandTitle('VIEWER'),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          LiveScreen(svc: _svc),
          ClipsScreen(
            title: 'Clips',
            emptyHint: 'No clips yet.\nWhile watching a camera, tap Record to save a clip here.',
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
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Clips',
          ),
        ],
      ),
    );
  }
}
