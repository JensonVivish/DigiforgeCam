import 'rtdb.dart';

class IceConfig {
  static const List<Map<String, dynamic>> _stun = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    },
  ];

  /// STUN by default. If you add a TURN entry at /config/turn in the database
  /// (a map or a list of maps with urls / username / credential), both apps
  /// pick it up on the next connection - no rebuild needed.
  static Future<List<Map<String, dynamic>>> load(Rtdb db) async {
    final servers = <Map<String, dynamic>>[..._stun];
    try {
      final t = await db.get('config/turn');
      final entries = t is List ? t : (t is Map ? [t] : const []);
      for (final e in entries) {
        if (e is Map && e['urls'] != null) {
          servers.add({
            'urls': e['urls'],
            if (e['username'] != null) 'username': e['username'],
            if (e['credential'] != null) 'credential': e['credential'],
          });
        }
      }
    } catch (_) {}
    return servers;
  }
}
