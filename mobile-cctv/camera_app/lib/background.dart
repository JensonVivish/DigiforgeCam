import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_service.dart';

class BgStatus {
  const BgStatus({
    this.ok = true,
    this.running = false,
    this.notifications = true,
    this.batteryExempt = false,
    this.overlay = false,
    this.manufacturer = '',
    this.sdk = 0,
  });

  /// False when the native side is missing from this build (channel not answering).
  final bool ok;
  final bool running;
  final bool notifications;
  final bool batteryExempt;
  final bool overlay;
  final String manufacturer;
  final int sdk;

  bool get needsVendorStep =>
      manufacturer.contains('samsung') ||
      manufacturer.contains('realme') ||
      manufacturer.contains('oppo') ||
      manufacturer.contains('oneplus');

  static BgStatus fromMap(Map<String, dynamic> m) => BgStatus(
        running: m['running'] == true,
        notifications: m['notifications'] != false,
        batteryExempt: m['batteryExempt'] == true,
        overlay: m['overlay'] == true,
        manufacturer: (m['manufacturer'] as String?) ?? '',
        sdk: (m['sdk'] as int?) ?? 0,
      );
}

/// Thin wrapper around the native platform channel (tools/native/Bridge.kt.tmpl).
class BackgroundBridge {
  static const MethodChannel _ch = MethodChannel('digiforge/background');

  static Future<bool> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      final v = await _ch.invokeMethod<dynamic>(method, args);
      return v == true;
    } catch (_) {
      return false;
    }
  }

  static Future<BgStatus> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('status');
      return m == null ? const BgStatus(ok: false) : BgStatus.fromMap(m);
    } catch (_) {
      return const BgStatus(ok: false);
    }
  }

  static Future<bool> start(String text) => _call('start', {'text': text});
  static Future<bool> setStatus(String text) => _call('setStatus', {'text': text});
  static Future<bool> requestNotifications() => _call('requestNotifications');
  static Future<bool> requestBattery() => _call('requestBatteryExemption');
  static Future<bool> requestOverlay() => _call('requestOverlay');
  static Future<bool> openVendorSettings() => _call('openVendorSettings');
  static Future<bool> moveToBackground() => _call('moveToBackground');
  static Future<bool> consumeAutostartLaunch() => _call('consumeAutostartLaunch');
}

/// Keeps the foreground service running and its notification text current.
/// There are no switches: background running is always on.
class BackgroundController extends ChangeNotifier {
  BackgroundController(this.svc);

  final CameraService svc;
  BgStatus status = const BgStatus();
  bool vendorDone = false;
  String _lastText = '';
  bool _disposed = false;

  static const _kVendorDone = 'vendor_done';

  void _n() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    vendorDone = p.getBool(_kVendorDone) ?? false;
    svc.onReady = _onCameraReady;
    svc.addListener(_onSvc);
    await refresh();
  }

  Future<void> refresh() async {
    status = await BackgroundBridge.status();
    _n();
  }

  Future<void> markVendorDone() async {
    vendorDone = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kVendorDone, true);
    _n();
  }

  String get _text => svc.live
      ? 'LIVE - ${svc.viewers} watching'
      : 'Standby - waiting for a viewer';

  /// The camera is up: make sure the foreground service is running too.
  Future<void> _onCameraReady() async {
    await refresh();
    _lastText = _text;
    if (status.running) {
      await BackgroundBridge.setStatus(_lastText);
    } else {
      await BackgroundBridge.start(_lastText);
      await refresh();
    }
    // Opened by the boot receiver (Android 11+ path): get out of the way.
    if (await BackgroundBridge.consumeAutostartLaunch()) {
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

  @override
  void dispose() {
    _disposed = true;
    svc.removeListener(_onSvc);
    super.dispose();
  }
}
