import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Remembers the last camera code that connected, for one-tap reconnect.
class RecentCameraStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/last_camera.txt');
  }

  static Future<String?> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final code = (await f.readAsString()).trim();
        if (RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code)) return code;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> save(String code) async {
    try {
      final f = await _file();
      await f.writeAsString(code);
    } catch (_) {}
  }
}
