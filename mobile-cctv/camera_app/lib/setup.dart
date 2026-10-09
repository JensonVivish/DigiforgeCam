import 'dart:async';

import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'background.dart';
import 'runtime.dart';

/// One-time setup. It starts by itself when the app opens: Android's own
/// permission dialogs appear one after another (tap Allow on each), with no
/// trips to the Settings app. When everything is allowed the screen closes
/// itself; the camera app never has to be opened again.
class SetupGate extends StatefulWidget {
  const SetupGate({super.key});

  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> with WidgetsBindingObserver {
  bool _skipped = false;
  bool _running = false;
  Completer<void>? _resume;
  bool _left = false; // a system dialog covered the app
  Timer? _closeTimer;

  BackgroundController get _bg => backgroundController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bg.refresh();
      if (!_allGranted && mounted) _allowAll(); // no button press needed
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _left = true;
    if (state == AppLifecycleState.resumed) {
      final c = _resume;
      if (c != null && !c.isCompleted) c.complete();
      _bg.refresh();
      if (_canClose) _scheduleClose(); // opened again later: just close again
    }
  }

  bool get _cameraOk {
    final s = _bg.status;
    return s.ok ? (s.camera && s.mic) : cameraService.accessGranted;
  }

  bool get _allGranted {
    final s = _bg.status;
    if (!s.ok) return _cameraOk;
    final batteryOk = s.sdk < 23 || s.batteryExempt;
    return _cameraOk && s.notifications && batteryOk;
  }

  bool get _canClose => (_allGranted || _skipped) && _bg.status.ok;

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 1200), () async {
      if (!_canClose) return;
      await _bg.ensureService();
      // From now on the launcher icon opens nothing at all.
      if (_allGranted) await BackgroundBridge.setSetupDone(true);
      await BackgroundBridge.closeApp();
    });
  }

  /// Opens a system dialog and waits until the user is back in the app.
  Future<void> _step(Future<bool> Function() open) async {
    final c = Completer<void>();
    _resume = c;
    _left = false;
    final launched = await open();
    if (launched) {
      // Give the dialog a moment to appear; if nothing covers the app, move on.
      await Future.any([c.future, Future<void>.delayed(const Duration(seconds: 3))]);
      if (_left && !c.isCompleted) {
        await c.future.timeout(const Duration(seconds: 120), onTimeout: () {});
      }
    }
    _resume = null;
    await _bg.refresh();
  }

  Future<void> _allowAll() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      // 1. Camera + microphone: Android's own dialogs (the camera itself is NOT started)
      if (!_cameraOk) {
        await _step(BackgroundBridge.requestCameraMic);
      }
      var s = _bg.status;
      // 2. Notifications (Android 13+ only)
      if (s.ok && !s.notifications) {
        await _step(BackgroundBridge.requestNotifications);
        s = _bg.status;
      }
      // 3. Keep running in the background (a system dialog, not the Settings app)
      if (s.ok && s.sdk >= 23 && !s.batteryExempt) {
        await _step(BackgroundBridge.requestBattery);
      }
      await _bg.ensureService(); // start it now that permissions exist
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_bg, cameraService]),
      builder: (context, _) {
        final s = _bg.status;
        final done = _skipped || _allGranted;
        return Scaffold(
          appBar: AppBar(toolbarHeight: 64, title: const BrandTitle('CAMERA')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (!s.ok)
                _Warn('The background service is not available in this build.\n\n'
                    'Reason: ${s.error}'),
              if (done) ..._donePage() else ..._setupPage(s),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _donePage() {
    if (_canClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleClose());
    }
    return [
      const SizedBox(height: 40),
      const Icon(Icons.check_circle_rounded, size: 72, color: DF.accent),
      const SizedBox(height: 16),
      const Center(
        child: Text('All set',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 8),
      const Text(
        'The camera app now runs in the background. The camera and microphone '
        'only turn on when you press Turn on in the viewer app. This screen closes automatically.',
        textAlign: TextAlign.center,
        style: TextStyle(color: DF.muted),
      ),
    ];
  }

  List<Widget> _setupPage(BgStatus s) {
    return [
      const Text('Allow everything once',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text(
        'Tap Allow on each Android dialog that appears. Nothing here opens the Settings app.',
        style: TextStyle(color: DF.muted),
      ),
      const SizedBox(height: 20),
      _Row('Camera and microphone', _cameraOk),
      if (s.ok && s.sdk >= 33) _Row('Notifications', s.notifications),
      if (s.ok && s.sdk >= 23) _Row('Keep running in background', s.batteryExempt),
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
    ];
  }
}

class _Warn extends StatelessWidget {
  const _Warn(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DF.danger.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DF.danger.withAlpha(140)),
      ),
      child: Text(text, style: const TextStyle(color: DF.danger, fontSize: 13)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.ok);
  final String title;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: ok ? DF.accent : DF.muted),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
