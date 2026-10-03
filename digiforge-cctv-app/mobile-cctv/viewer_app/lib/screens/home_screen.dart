import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';
import 'clips_screen.dart';

/// Bottom-nav shell: Connect (scan a camera's QR) and Clips (saved recordings).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [ScanScreen(), ClipsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: DigiforgeBrand.surface,
        selectedItemColor: DigiforgeBrand.accent,
        unselectedItemColor: DigiforgeBrand.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Connect'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library_outlined), label: 'Clips'),
        ],
      ),
    );
  }
}
