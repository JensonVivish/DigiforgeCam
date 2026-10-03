import 'package:flutter/material.dart';
import 'theme.dart';

/// Placeholder brand mark. Swap for the real DigiforgeDynamics logo asset later.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: [DF.accent, DF.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        'DF',
        style: TextStyle(
          color: const Color(0xFF04201E),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.42,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle(this.subtitle, {super.key});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 34),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DigiforgeDynamics',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: DF.muted, letterSpacing: 1.6)),
          ],
        ),
      ],
    );
  }
}
