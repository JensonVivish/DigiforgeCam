import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

/// Keeps the camera's pairing code across app restarts, so a viewer can
/// reconnect automatically after the camera phone reboots or the app is killed.
class PairingStore {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final RegExp _valid = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

  static String generate() {
    final rng = Random.secure();
    return List.generate(6, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pairing_code.txt');
  }

  static Future<String> loadOrCreate() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final code = (await f.readAsString()).trim();
        if (_valid.hasMatch(code)) return code;
      }
    } catch (_) {}
    return createNew();
  }

  static Future<String> createNew() async {
    final code = generate();
    try {
      final f = await _file();
      await f.writeAsString(code);
    } catch (_) {}
    return code;
  }
}
