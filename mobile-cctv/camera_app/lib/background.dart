import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_service.dart';

class BgStatus {
  const BgStatus({
    this.running = false,
    this.notifications = true,
    this.batteryExempt = false,
    this.overlay = false,
    this.autostart = false,
    this.manufacturer = '',
    this.sdk = 0,
  });

  final bool running;
  final bool notifications;
  final bool batteryExempt;
  final bool overlay;
  final bool autostart;
  final String manufacturer;
  final int sdk;

  static BgStatus fromMap(Map<String, dynamic> m) => BgStatus(
        running: m['running'] == true,
        notifications: m['notifications'] != false,
        batteryExempt: m['batteryExempt'] == true,
        overlay: m['overlay'] == true,
        autostart: m['autostart'] == true,
        manufacturer: (m['manufacturer'] as String?) ?? '',
        sdk: (m['sdk'] as int?) ?? 0,
      );
}

/// Thin wrapper around the native platform channel (see tools/native/Bridge.kt.tmpl).
class BackgroundBridge {
  static const MethodChannel _ch = MethodChannel('digiforge/background');

  static Future<bool> _ok(String method, [Map<String, dynamic>? args]) async {
    try {
      await _ch.invokeMethod<dynamic>(method, args);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<BgStatus> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('status');
      return m == null ? const BgStatus() : BgStatus.fromMap(m);
    } catch (_) {
      return const BgStatus();
    }
  }

  static Future<bool> start(String text) => _ok('start', {'text': text});
  static Future<bool> stop() => _ok('stop');
  static Future<bool> setStatus(String text) => _ok('setStatus', {'text': text});
  static Future<bool> setAutostart(bool v) => _ok('setAutostart', {'value': v});
  static Future<bool> requestNotifications() => _ok('requestNotifications');
  static Future<bool> requestBattery() => _ok('requestBatteryExemption');
  static Future<bool> requestOverlay() => _ok('requestOverlay');
  static Future<bool> openVendorSettings() => _ok('openVendorSettings');
  static Future<bool> openAppSettings() => _ok('openAppSettings');
  static Future<bool> moveToBackground() => _ok('moveToBackground');

  static Future<bool> consumeAutostartLaunch() async {
    try {
      final v = await _ch.invokeMethod<bool>('consumeAutostartLaunch');
      return v == true;
    } catch (_) {
      return false;
    }
  }
}

/// Owns the "background mode" state: starts/stops the foreground service,
/// keeps its notification text in sync, and handles the boot-launch flow.
class BackgroundController extends ChangeNotifier {
  BackgroundController(this.svc);

  final CameraService svc;
  BgStatus status = const BgStatus();
  bool bgMode = true; // on by default: background mode is the point of the app
  String _lastText = '';
  bool _disposed = false;

  static const _kBgMode = 'bg_mode';

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    bgMode = p.getBool(_kBgMode) ?? true;
    svc.onReady = _onCameraReady;
    svc.addListener(_onSvc);
    await refresh();
  }

  Future<void> refresh() async {
    status = await BackgroundBridge.status();
    _n();
  }

  void _refreshSoon() {
    Future<void>.delayed(const Duration(milliseconds: 1500), refresh);
  }

  String get _text {
    if (svc.live) {
      return 'LIVE - ${svc.viewers} viewer${svc.viewers == 1 ? '' : 's'} watching';
    }
    return 'Standby - waiting for a viewer';
  }

  Future<void> _startService() async {
    _lastText = _text;
    await BackgroundBridge.start(_lastText);
    await refresh();
  }

  /// Called once the camera stream is up (the Activity is visible at this point,
  /// which is what Android requires to start a camera foreground service).
  Future<void> _onCameraReady() async {
    await refresh();
    if (bgMode) {
      if (status.running) {
        // Service already up (for example started by the boot receiver).
        _lastText = _text;
        await BackgroundBridge.setStatus(_lastText);
      } else {
        await _startService();
      }
    }
    if (await BackgroundBridge.consumeAutostartLaunch()) {
      // Launched by the boot receiver: let the service settle, then get out of the way.
      await Future<void>.delayed(const Duration(seconds: 4));
      await BackgroundBridge.moveToBackground();
    }
  }

  void _onSvc() {
    if (status.running && _text != _lastText) {
      _lastText = _text;
      BackgroundBridge.setStatus(_lastText);
    }
  }

  Future<void> setBgMode(bool v) async {
    bgMode = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBgMode, v);
    if (v) {
      if (svc.started || svc.stream != null) await _startService();
    } else {
      await BackgroundBridge.stop();
      await refresh();
    }
    _n();
  }

  Future<void> setAutostart(bool v) async {
    await BackgroundBridge.setAutostart(v);
    await refresh();
  }

  Future<void> requestNotifications() async {
    await BackgroundBridge.requestNotifications();
    _refreshSoon();
  }

  Future<void> requestBattery() async {
    await BackgroundBridge.requestBattery();
    _refreshSoon();
  }

  Future<void> requestOverlay() async {
    await BackgroundBridge.requestOverlay();
    _refreshSoon();
  }

  Future<void> openVendor() => BackgroundBridge.openVendorSettings();
  Future<void> openAppSettings() => BackgroundBridge.openAppSettings();

  @override
  void dispose() {
    _disposed = true;
    svc.removeListener(_onSvc);
    super.dispose();
  }
}
