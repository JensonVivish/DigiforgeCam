import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'viewer_service.dart';

String _mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.svc});
  final ViewerService svc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ConfigNotice(),
            if (svc.state == ViewerState.idle) ..._channelList() else ..._watching(),
          ],
        );
      },
    );
  }

  List<Widget> _channelList() {
    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Cameras',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ),
      if (svc.listError != null)
        Text(svc.listError!, style: const TextStyle(color: DF.danger)),
      if (svc.scanning && svc.channels.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (svc.channels.isEmpty && svc.listError == null)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No cameras online.\nMake sure the camera app has been set up and the phone is connected to the internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DF.muted),
          ),
        ),
      for (final c in svc.channels)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: DF.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DF.line),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DF.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam_rounded, color: DF.accent),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.watching ? 'In use - someone is watching' : 'Ready - camera is off',
                style: const TextStyle(color: DF.muted)),
            trailing: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
              onPressed: () => svc.connect(c.code),
              child: const Text('Turn on'),
            ),
          ),
        ),
    ];
  }

  List<Widget> _watching() {
    final live = svc.state == ViewerState.live;
    final String status;
    switch (svc.state) {
      case ViewerState.live:
        status = 'Live';
        break;
      case ViewerState.connecting:
        status = 'Turning on camera...';
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
                  label: live ? 'LIVE' : 'STARTING',
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
              if (live && svc.facing.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: StatusBadge(
                    label: svc.facing == 'user' ? 'FRONT CAMERA' : 'BACK CAMERA',
                    color: DF.accent,
                  ),
                ),
              if (live)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IconButton.filled(
                    onPressed: svc.switching ? null : svc.switchCamera,
                    icon: const Icon(Icons.cameraswitch_rounded),
                    tooltip: 'Switch camera',
                  ),
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
        icon: const Icon(Icons.power_settings_new_rounded),
        label: const Text('Turn off camera'),
      ),
      if (svc.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(svc.error!, style: const TextStyle(color: DF.danger)),
        ),
    ];
  }
}
