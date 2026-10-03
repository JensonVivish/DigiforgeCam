import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'scan_screen.dart';
import 'viewer_service.dart';

String _mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.svc});
  final ViewerService svc;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String? _err;

  ViewerService get svc => widget.svc;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (code != null) svc.connect(code);
  }

  void _typed() {
    final code = PairingCode.parse(_ctrl.text);
    if (code == null) {
      setState(() => _err = 'Enter the 6-character code');
      return;
    }
    setState(() => _err = null);
    FocusScope.of(context).unfocus();
    svc.connect(code);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ConfigNotice(),
            if (svc.state == ViewerState.idle) ..._pairing() else ..._watching(),
          ],
        );
      },
    );
  }

  List<Widget> _pairing() {
    final last = svc.lastCode;
    return [
      if (last != null) ...[
        DFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Last camera'),
              const SizedBox(height: 6),
              Text(last,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: DF.accent)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => svc.connect(last),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reconnect'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: svc.forgetLast, child: const Text('Forget this camera')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      DFCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Pair a camera'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan QR code'),
            ),
            const SizedBox(height: 14),
            const Center(
                child: Text('or enter the code', style: TextStyle(color: DF.muted))),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
              decoration: InputDecoration(hintText: 'A3K8PZ', errorText: _err),
              onSubmitted: (_) => _typed(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _typed, child: const Text('Connect')),
          ],
        ),
      ),
      if (svc.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(svc.error!, style: const TextStyle(color: DF.danger)),
        ),
    ];
  }

  List<Widget> _watching() {
    final live = svc.state == ViewerState.live;
    final String status;
    switch (svc.state) {
      case ViewerState.live:
        status = 'Live from ${svc.target}';
        break;
      case ViewerState.connecting:
        status = 'Connecting to ${svc.target}...';
        break;
      default:
        status = svc.retryIn > 0
            ? 'Connection lost. Retrying in ${svc.retryIn}s'
            : 'Reconnecting...';
    }

    final String camLabel;
    final Color camColor;
    if (svc.cameraOnline == true) {
      camLabel = 'CAMERA ONLINE';
      camColor = DF.accent;
    } else if (svc.cameraOnline == false) {
      camLabel = 'CAMERA OFFLINE';
      camColor = DF.warn;
    } else {
      camLabel = 'CHECKING CAMERA';
      camColor = DF.muted;
    }

    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              if (live)
                RTCVideoView(
                  svc.renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(status, style: const TextStyle(color: DF.muted)),
                    ],
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: StatusBadge(
                  label: live ? 'LIVE' : 'CONNECTING',
                  color: live ? DF.danger : DF.warn,
                ),
              ),
              if (svc.recording)
                Positioned(
                  top: 12,
                  right: 12,
                  child: StatusBadge(
                      label: 'REC ${_mmss(svc.recElapsed)}', color: DF.danger),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      DFCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            StatusBadge(label: camLabel, color: camColor),
          ],
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        style: svc.recording
            ? FilledButton.styleFrom(
                backgroundColor: DF.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              )
            : null,
        onPressed: live ? svc.toggleRecording : null,
        icon: Icon(svc.recording
            ? Icons.stop_rounded
            : Icons.fiber_manual_record_rounded),
        label: Text(svc.recording ? 'Stop and save clip' : 'Record clip'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: svc.disconnect,
        icon: const Icon(Icons.close_rounded),
        label: const Text('Disconnect'),
      ),
      if (svc.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(svc.error!, style: const TextStyle(color: DF.danger)),
        ),
    ];
  }
}
