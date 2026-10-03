import 'package:flutter/material.dart';
import 'config.dart';
import 'theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0E13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(160)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class DFCard extends StatelessWidget {
  const DFCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: DF.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DF.line),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: DF.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// Shown when the Firebase database URL has not been filled in yet.
class ConfigNotice extends StatelessWidget {
  const ConfigNotice({super.key});

  @override
  Widget build(BuildContext context) {
    if (dbConfigured) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DF.warn.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DF.warn.withAlpha(140)),
      ),
      child: const Text(
        'Firebase database URL is not set. Edit shared/lib/src/config.dart '
        'and rebuild, otherwise pairing cannot work.',
        style: TextStyle(color: DF.warn, fontSize: 13),
      ),
    );
  }
}
