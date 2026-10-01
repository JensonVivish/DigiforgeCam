import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small brand lockup used in app bars across both Digiforge CCTV apps.
class DigiforgeBrandHeader extends StatelessWidget {
  final String appLabel;
  const DigiforgeBrandHeader({super.key, required this.appLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [DigiforgeBrand.accent, DigiforgeBrand.accentDim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.videocam_rounded, color: Color(0xFF04211D), size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DIGIFORGEDYNAMICS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: DigiforgeBrand.textSecondary,
                    fontWeight: FontWeight.w600)),
            Text(appLabel,
                style: const TextStyle(
                    fontSize: 16, color: DigiforgeBrand.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
