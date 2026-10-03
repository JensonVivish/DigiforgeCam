import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'theme.dart';

class ClipsStore {
  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/clips');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> newPath(String prefix) async {
    final d = await dir();
    return '${d.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  static Future<List<File>> list() async {
    final d = await dir();
    final files = d
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _stamp(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${_months[d.month - 1]} ${d.day}, ${d.year}  $h:$m';
}

String _size(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Browse, play and delete locally saved clips. Used by both apps.
class ClipsScreen extends StatefulWidget {
  const ClipsScreen({
    super.key,
    required this.title,
    required this.emptyHint,
    this.refresh,
  });
  final String title;
  final String emptyHint;
  final ValueListenable<int>? refresh;

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  List<File>? _files;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final f = await ClipsStore.list();
    if (mounted) setState(() => _files = f);
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete clip?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await f.delete();
      } catch (_) {}
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Expanded(
            child: files == null
                ? const Center(child: CircularProgressIndicator())
                : files.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(widget.emptyHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: DF.muted)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (context, i) {
                            final f = files[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: DF.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: DF.line),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: DF.accentSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: DF.accent),
                                ),
                                title: Text(_stamp(f.lastModifiedSync()),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(_size(f.lengthSync()),
                                    style: const TextStyle(color: DF.muted)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(f),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ClipPlayerPage(file: f)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class ClipPlayerPage extends StatefulWidget {
  const ClipPlayerPage({super.key, required this.file});
  final File file;

  @override
  State<ClipPlayerPage> createState() => _ClipPlayerPageState();
}

class _ClipPlayerPageState extends State<ClipPlayerPage> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(widget.file);
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_failed) {
      body = const Text('Could not play this clip',
          style: TextStyle(color: DF.muted));
    } else if (!_ready) {
      body = const CircularProgressIndicator();
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
              aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
          VideoProgressIndicator(_c,
              allowScrubbing: true, padding: const EdgeInsets.all(16)),
          IconButton(
            iconSize: 56,
            color: DF.accent,
            icon: Icon(_c.value.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill),
            onPressed: () {
              if (_c.value.isPlaying) {
                _c.pause();
              } else {
                _c.play();
              }
            },
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Clip')),
      body: Center(child: body),
    );
  }
}
