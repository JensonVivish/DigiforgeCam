import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'background.dart';
import 'camera_service.dart';

/// Deliberately minimal: the preview, a camera flip button, the code and the QR.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key, required this.svc, required this.bg});
  final CameraService svc;
  final BackgroundController bg;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([svc, bg]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ConfigNotice(),
            if (!bg.status.ok) const _MissingNative(),
            _Preview(svc: svc),
            const SizedBox(height: 16),
            _PairingCard(svc: svc),
          ],
        );
      },
    );
  }
}

class _MissingNative extends StatelessWidget {
  const _MissingNative();

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
      child: const Text(
        'The background service is missing from this build, so the camera will '
        'stop when the app is closed. Upload the whole mobile-cctv folder '
        '(including tools/native) and run Build APKs again.',
        style: TextStyle(color: DF.danger, fontSize: 13),
      ),
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
        aspectRatio: 4 / 3,
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
                          size: 44, color: DF.muted),
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
            Positioned(
              right: 10,
              bottom: 10,
              child: IconButton.filled(
                onPressed: svc.stream == null ? null : svc.switchFacing,
                icon: const Icon(Icons.cameraswitch_rounded),
                tooltip: 'Switch camera',
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
          // Big and high-contrast so the viewer can scan it easily.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: PairingCode.qrPayload(svc.code),
              size: 230,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
