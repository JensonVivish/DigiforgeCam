import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'camera_service.dart';

String _mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key, required this.svc});
  final CameraService svc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ConfigNotice(),
            _Preview(svc: svc),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: svc.recording
                  ? FilledButton.styleFrom(
                      backgroundColor: DF.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    )
                  : null,
              onPressed: svc.stream == null ? null : svc.toggleRecording,
              icon: Icon(svc.recording
                  ? Icons.stop_rounded
                  : Icons.fiber_manual_record_rounded),
              label: Text(svc.recording ? 'Stop recording' : 'Record clip'),
            ),
            const SizedBox(height: 16),
            _PairingCard(svc: svc),
          ],
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.svc});
  final CameraService svc;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            if (svc.stream != null)
              RTCVideoView(
                svc.renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined,
                          size: 48, color: DF.muted),
                      const SizedBox(height: 10),
                      Text(
                        svc.error ?? 'Starting camera...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DF.muted),
                      ),
                      if (svc.error != null)
                        TextButton(
                            onPressed: svc.start, child: const Text('Try again')),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: StatusBadge(
                label: svc.live ? 'LIVE' : 'STANDBY',
                color: svc.live ? DF.danger : DF.warn,
              ),
            ),
            if (svc.recording)
              Positioned(
                top: 12,
                right: 12,
                child: StatusBadge(
                  label: 'REC ${_mmss(svc.recElapsed)}',
                  color: DF.danger,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.svc});
  final CameraService svc;

  @override
  Widget build(BuildContext context) {
    return DFCard(
      child: Column(
        children: [
          const SectionLabel('Pairing code'),
          const SizedBox(height: 8),
          SelectableText(
            svc.code,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: DF.accent,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              data: PairingCode.qrPayload(svc.code),
              size: 170,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'In the Viewer app, scan this QR or type the code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DF.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            svc.viewers == 1 ? '1 viewer connected' : '${svc.viewers} viewers connected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
