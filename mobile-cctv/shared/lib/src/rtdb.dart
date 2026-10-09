import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class RtdbException implements Exception {
  RtdbException(this.message);
  final String message;
  @override
  String toString() => 'RtdbException: $message';
}

/// Tiny Firebase Realtime Database client over the REST API.
/// No Firebase SDK or google-services.json needed.
class Rtdb {
  Rtdb([String? baseUrl])
      : _base = (baseUrl ?? kDatabaseUrl).replaceAll(RegExp(r'/+$'), '');

  final String _base;
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

  Uri _uri(String path) => Uri.parse('$_base/$path.json');

  Future<dynamic> get(String path) async {
    final r = await _client.get(_uri(path)).timeout(_timeout);
    _check(r, 'GET', path);
    return jsonDecode(r.body);
  }

  Future<void> put(String path, Object? data) async {
    final r = await _client.put(_uri(path), body: jsonEncode(data)).timeout(_timeout);
    _check(r, 'PUT', path);
  }

  /// PUT that returns what the server stored. With a server value such as
  /// {".sv": "timestamp"} this is the server's current time in milliseconds.
  Future<dynamic> putGet(String path, Object? data) async {
    final r = await _client.put(_uri(path), body: jsonEncode(data)).timeout(_timeout);
    _check(r, 'PUT', path);
    return jsonDecode(r.body);
  }

  /// Child keys of [path] without downloading the data below them.
  Future<List<String>> getShallow(String path) async {
    final uri = Uri.parse('$_base/$path.json?shallow=true');
    final r = await _client.get(uri).timeout(_timeout);
    _check(r, 'GET', path);
    final j = jsonDecode(r.body);
    return j is Map ? j.keys.map((k) => k.toString()).toList() : <String>[];
  }

  /// Appends [data] under a new unique key and returns that key.
  Future<String?> push(String path, Object? data) async {
    final r = await _client.post(_uri(path), body: jsonEncode(data)).timeout(_timeout);
    _check(r, 'POST', path);
    final j = jsonDecode(r.body);
    return j is Map ? j['name'] as String? : null;
  }

  Future<void> delete(String path) async {
    final r = await _client.delete(_uri(path)).timeout(_timeout);
    _check(r, 'DELETE', path);
  }

  void _check(http.Response r, String verb, String path) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw RtdbException('$verb $path -> ${r.statusCode} ${r.body}');
    }
  }
}
