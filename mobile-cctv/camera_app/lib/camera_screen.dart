import 'package:digiforge_shared/digiforge_shared.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'background.dart';
import 'camera_service.dart';

/// Deliberately minimal: only the pairing code (and its QR). No preview.
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
            if (!bg.status.ok)
              _Warn(
                'The background service is not available in this build, so the camera '
                'will stop when the app is closed.\n\nReason: ${bg.status.error}',
              ),
            if (svc.error != null) _Warn(svc.error!),
            DFCard(
              child: Column(
                children: [
                  const SectionLabel('Pairing code'),
                  const SizedBox(height: 8),
                  SelectableText(
                    svc.code,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: DF.accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: PairingCode.qrPayload(svc.code),
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
