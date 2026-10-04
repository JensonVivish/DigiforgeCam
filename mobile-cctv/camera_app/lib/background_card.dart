import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';

import 'background.dart';

class BackgroundCard extends StatefulWidget {
  const BackgroundCard({super.key, required this.bg});
  final BackgroundController bg;

  @override
  State<BackgroundCard> createState() => _BackgroundCardState();
}

class _BackgroundCardState extends State<BackgroundCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.bg.refresh();
  }

  String _vendorLabel(String m) {
    if (m.contains('samsung')) return 'Open Samsung battery settings';
    if (m.contains('realme') || m.contains('oppo') || m.contains('oneplus')) {
      return 'Open Realme auto-launch settings';
    }
    return 'Open app settings';
  }

  String _vendorHelp(String m) {
    if (m.contains('samsung')) {
      return 'Samsung: Settings > Device care (or Battery) > Battery > App power '
          'management (or Background usage limits) > add DigiForge Camera to '
          'the apps that never sleep. Switch off "Put unused apps to sleep". '
          'Menu names vary by version.';
    }
    if (m.contains('realme') || m.contains('oppo') || m.contains('oneplus')) {
      return 'Realme: Settings > App management (or Apps) > DigiForge Camera: '
          'turn on Auto launch and allow background activity, and set battery '
          'usage to unrestricted / don\'t optimise. Menu names vary by version.';
    }
    return 'If the camera stops after a while, allow background activity and '
        'auto-start for this app in your phone\'s battery settings.';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.bg;
    return ListenableBuilder(
      listenable: Listenable.merge([bg, bg.svc]),
      builder: (context, _) {
        final s = bg.status;
        return DFCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionLabel('Background mode')),
                  StatusBadge(
                    label: s.running ? 'RUNNING' : 'OFF',
                    color: s.running ? DF.accent : DF.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: bg.bgMode,
                onChanged: bg.setBgMode,
                title: const Text('Keep running in background'),
                subtitle: const Text(
                  'Shows a notification. The camera stays live with the screen off.',
                  style: TextStyle(color: DF.muted, fontSize: 12),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.autostart,
                onChanged: bg.setAutostart,
                title: const Text('Start when phone reboots'),
                subtitle: Text(
                  s.sdk >= 30
                      ? 'Opens the app after a reboot (after you unlock once).'
                      : 'Starts the camera by itself after a reboot.',
                  style: const TextStyle(color: DF.muted, fontSize: 12),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: bg.svc.saver,
                onChanged: bg.svc.setSaver,
                title: const Text('Battery saver'),
                subtitle: const Text(
                  'Turns the camera off when nobody is watching. It wakes in a second or two when you connect.',
                  style: TextStyle(color: DF.muted, fontSize: 12),
                ),
              ),
              const Divider(color: DF.line, height: 24),
              _CheckRow(
                title: 'Notifications',
                ok: s.notifications,
                action: 'Allow',
                onTap: bg.requestNotifications,
              ),
              if (s.sdk >= 23)
                _CheckRow(
                  title: 'Unrestricted battery',
                  ok: s.batteryExempt,
                  action: 'Allow',
                  onTap: bg.requestBattery,
                ),
              if (s.sdk >= 30)
                _CheckRow(
                  title: 'Display over other apps',
                  hint: 'Lets the app open itself after a reboot',
                  ok: s.overlay,
                  action: 'Allow',
                  onTap: bg.requestOverlay,
                ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: bg.openVendor,
                child: Text(_vendorLabel(s.manufacturer)),
              ),
              const SizedBox(height: 10),
              Text(
                _vendorHelp(s.manufacturer),
                style: const TextStyle(color: DF.muted, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: bg.openAppSettings,
                  child: const Text('App settings'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.ok,
    required this.action,
    required this.onTap,
    this.hint,
  });
  final String title;
  final String? hint;
  final bool ok;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: ok ? DF.accent : DF.warn,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (hint != null)
                  Text(hint!,
                      style: const TextStyle(color: DF.muted, fontSize: 12)),
              ],
            ),
          ),
          if (!ok) TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
