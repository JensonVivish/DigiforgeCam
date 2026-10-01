import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'clip_player_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  List<File> _clips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final dir = await getApplicationDocumentsDirectory();
    final clipsDir = Directory('${dir.path}/clips');
    if (!await clipsDir.exists()) {
      setState(() {
        _clips = [];
        _loading = false;
      });
      return;
    }
    final files =
        clipsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // newest first
    setState(() {
      _clips = files;
      _loading = false;
    });
  }

  Future<void> _delete(File file) async {
    await file.delete();
    _loadClips();
  }

  String _labelFor(String path) {
    final name = path.split('/').last.replaceFirst('clip_', '').replaceFirst('.mp4', '');
    return name.replaceFirst('T', '  ').split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Clips')),
      body: RefreshIndicator(
        color: DigiforgeBrand.accent,
        onRefresh: _loadClips,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DigiforgeBrand.accent))
            : _clips.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(48),
                        child: Text(
                          'No saved clips yet.\nWhile watching a live camera, tap record to save a clip here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: DigiforgeBrand.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _clips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = _clips[index];
                      final sizeMb = file.lengthSync() / (1024 * 1024);
                      return Container(
                        decoration: BoxDecoration(
                            color: DigiforgeBrand.surface, borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading:
                              const Icon(Icons.play_circle_fill, color: DigiforgeBrand.accent, size: 32),
                          title: Text(_labelFor(file.path),
                              style: const TextStyle(color: DigiforgeBrand.textPrimary)),
                          subtitle: Text('${sizeMb.toStringAsFixed(1)} MB',
                              style: const TextStyle(color: DigiforgeBrand.textSecondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: DigiforgeBrand.textSecondary),
                            onPressed: () => _delete(file),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ClipPlayerScreen(filePath: file.path)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
