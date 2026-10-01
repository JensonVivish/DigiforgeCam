import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

/// Records a MediaStreamTrack to an mp4 file on this device, using
/// flutter_webrtc's built-in MediaRecorder. Used here to save the remote
/// (camera's) video track — i.e. "save what I'm currently watching".
class RecordingService {
  MediaRecorder? _recorder;
  String? _currentFilePath;
  DateTime? _startedAt;

  bool get isRecording => _recorder != null;
  DateTime? get startedAt => _startedAt;

  Future<Directory> _clipsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final clipsDir = Directory('${dir.path}/clips');
    if (!await clipsDir.exists()) {
      await clipsDir.create(recursive: true);
    }
    return clipsDir;
  }

  Future<String> start(MediaStreamTrack videoTrack) async {
    final dir = await _clipsDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = '${dir.path}/clip_$timestamp.mp4';

    _recorder = MediaRecorder();
    await _recorder!.start(path, videoTrack: videoTrack);

    _currentFilePath = path;
    _startedAt = DateTime.now();
    return path;
  }

  Future<String?> stop() async {
    if (_recorder == null) return null;
    await _recorder!.stop();
    final path = _currentFilePath;
    _recorder = null;
    _currentFilePath = null;
    _startedAt = null;
    return path;
  }
}
