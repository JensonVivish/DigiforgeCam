import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PairingCode {
  // No I, O, 0, 1 so codes are easy to read and type.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _kOwn = 'own_pairing_code';
  static const _kLast = 'last_camera_code';

  static String generate() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  /// Camera side: the code is created once and kept forever.
  static Future<String> loadOrCreate() async {
    final p = await SharedPreferences.getInstance();
    var c = p.getString(_kOwn);
    if (c == null || c.length != 6) {
      c = generate();
      await p.setString(_kOwn, c);
    }
    return c;
  }

  /// Viewer side: remember the last camera for one-tap reconnect.
  static Future<String?> loadLast() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLast);
  }

  static Future<void> saveLast(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLast, code);
  }

  static Future<void> forgetLast() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLast);
  }

  static String qrPayload(String code) => 'DFCCTV:$code';

  /// Accepts a raw typed code or a scanned QR payload. Returns null if invalid.
  static String? parse(String raw) {
    var s = raw.trim().toUpperCase();
    if (s.startsWith('DFCCTV:')) s = s.substring(7);
    s = s.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(s) ? s : null;
  }
}
