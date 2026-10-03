import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../config/app_config.dart';

/// Loads optional TURN/STUN servers from Firebase (`config/ice_servers`) so
/// relay credentials can be changed without rebuilding the apps.
/// Always falls back to the built-in public STUN servers.
class IceConfigService {
  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('config/ice_servers')
          .get()
          .timeout(const Duration(seconds: 6));
      final value = snap.value;
      Iterable<dynamic> items = const [];
      if (value is List) {
        items = value;
      } else if (value is Map) {
        items = value.values;
      }
      final extra = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item is! Map) continue;
        final urls = _normalizeUrls(item['urls']);
        if (urls == null) continue;
        final entry = <String, dynamic>{'urls': urls};
        if (item['username'] != null) entry['username'] = item['username'].toString();
        if (item['credential'] != null) entry['credential'] = item['credential'].toString();
        extra.add(entry);
      }
      if (extra.isNotEmpty) {
        return [...extra, ...AppConfig.fallbackIceServers];
      }
    } catch (_) {
      // Offline, rules deny read, or node missing: use the fallback below.
    }
    return List<Map<String, dynamic>>.from(AppConfig.fallbackIceServers);
  }

  static dynamic _normalizeUrls(dynamic urls) {
    if (urls is String) return urls;
    if (urls is List) return urls.map((e) => e.toString()).toList();
    if (urls is Map) return urls.values.map((e) => e.toString()).toList();
    return null;
  }
}
