import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'live_view_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      final code = data['code'] as String;
      _handled = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveViewScreen(pairingCode: code),
        ),
      ).then((_) {
        // Allow scanning again when returning from live view
        if (mounted) setState(() => _handled = false);
      });
    } catch (_) {
      // Not a Digiforge CCTV QR — ignore and keep scanning
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Scan Camera')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: DigiforgeBrand.accent, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Corner accents on the scan box
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Point at the QR code shown\nin the Camera app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: DigiforgeBrand.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Powered by DigiforgeDynamics',
                  style: TextStyle(
                      color: DigiforgeBrand.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws cyan accent corners over the scan box for a CCTV-style look.
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const color = DigiforgeBrand.accent;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    final r = size.width;
    final b = size.height;
    // Top-left
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, len), paint);
    // Top-right
    canvas.drawLine(Offset(r, 0), Offset(r - len, 0), paint);
    canvas.drawLine(Offset(r, 0), Offset(r, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, b), Offset(len, b), paint);
    canvas.drawLine(Offset(0, b), Offset(0, b - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(r, b), Offset(r - len, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - len), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
