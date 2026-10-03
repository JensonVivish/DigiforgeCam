import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

/// Records a local MediaStreamTrack (the camera's own video) directly to an
/// mp4 file on this device, using flutter_webrtc's built-in MediaRecorder.
/// This runs independently of whether a viewer is currently connected —
/// it's local storage on the camera device itself, like a real CCTV unit.
class RecordingService {
  MediaRecorder? _recorder;
  String? _currentFilePath;
  DateTime? _startedAt;

  bool get isRecording => _recorder != null;
  DateTime? get startedAt => _startedAt;

  Future<Directory> _recordingsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  Future<String> start(MediaStreamTrack videoTrack) async {
    final dir = await _recordingsDir();
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
