import 'dart:async';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'background.dart';
import 'runtime.dart';

/// Asks for everything up front, in one go. Shows the main screen once all is
/// granted (or the user chooses to continue anyway).
class SetupGate extends StatefulWidget {
  const SetupGate({super.key, required this.child});
  final Widget child;

  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> with WidgetsBindingObserver {
  bool _skipped = false;
  bool _running = false;
  Completer<void>? _resume;

  BackgroundController get _bg => backgroundController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bg.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final c = _resume;
      if (c != null && !c.isCompleted) c.complete();
      _bg.refresh();
    }
  }

  bool get _cameraOk => cameraService.stream != null;

  bool get _allGranted {
    final s = _bg.status;
    if (!s.ok) return _cameraOk; // nothing native to ask for
    final batteryOk = s.sdk < 23 || s.batteryExempt;
    final overlayOk = s.sdk < 30 || s.overlay;
    final vendorOk = !s.needsVendorStep || _bg.vendorDone;
    return _cameraOk && s.notifications && batteryOk && overlayOk && vendorOk;
  }

  /// Runs a step that opens a system screen, then waits until the user returns.
  Future<void> _step(Future<bool> Function() open) async {
    final c = Completer<void>();
    _resume = c;
    final launched = await open();
    if (launched) {
      await c.future.timeout(const Duration(seconds: 120), onTimeout: () {});
    }
    _resume = null;
    await _bg.refresh();
  }

  Future<void> _allowAll() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      // 1. Camera + microphone (system dialog)
      await cameraService.ensureCamera();
      if (cameraService.stream != null && !cameraService.started) {
        await cameraService.start();
      }
      await _bg.refresh();
      var s = _bg.status;

      // 2. Notifications
      if (s.ok && !s.notifications) {
        await _step(BackgroundBridge.requestNotifications);
        s = _bg.status;
      }
      // 3. Keep running in the background (battery)
      if (s.ok && s.sdk >= 23 && !s.batteryExempt) {
        await _step(BackgroundBridge.requestBattery);
        s = _bg.status;
      }
      // 4. Open itself after reboot on Android 11+
      if (s.ok && s.sdk >= 30 && !s.overlay) {
        await _step(BackgroundBridge.requestOverlay);
        s = _bg.status;
      }
      // 5. Samsung / Realme auto-start screen (cannot be checked, so asked once)
      if (s.ok && s.needsVendorStep && !_bg.vendorDone) {
        await _step(BackgroundBridge.openVendorSettings);
        await _bg.markVendorDone();
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _vendorHint(String m) {
    if (m.contains('samsung')) {
      return 'Add DigiForge Camera to the apps that never sleep.';
    }
    return 'Turn on Auto launch and allow background activity.';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_bg, cameraService]),
      builder: (context, _) {
        if (_skipped || _allGranted) return widget.child;
        final s = _bg.status;
        return Scaffold(
          appBar: AppBar(toolbarHeight: 64, title: const BrandTitle('CAMERA')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text('Allow everything once',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'So the camera keeps running in the background and starts by itself after a reboot.',
                style: TextStyle(color: DF.muted),
              ),
              const SizedBox(height: 20),
              _Row('Camera and microphone', _cameraOk),
              if (s.ok && s.sdk >= 33) _Row('Notifications', s.notifications),
              if (s.ok && s.sdk >= 23)
                _Row('Keep running in background', s.batteryExempt),
              if (s.ok && s.sdk >= 30)
                _Row('Open after reboot (display over other apps)', s.overlay),
              if (s.ok && s.needsVendorStep)
                _Row('Start after reboot', _bg.vendorDone,
                    hint: _vendorHint(s.manufacturer)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _running ? null : _allowAll,
                child: Text(_running ? 'Working...' : 'Allow all'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _skipped = true),
                child: const Text('Continue anyway'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.ok, {this.hint});
  final String title;
  final bool ok;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: ok ? DF.accent : DF.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (hint != null && !ok)
                  Text(hint!,
                      style: const TextStyle(color: DF.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
