import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/recent_camera_store.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'live_view_screen.dart';

final RegExp _codeRe = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _opening = false;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLast() async {
    final c = await RecentCameraStore.load();
    if (mounted) setState(() => _lastCode = c);
  }

  /// Accepts the camera's QR (JSON with a code) or a plain 6-character code.
  String? _parse(String raw) {
    final text = raw.trim();
    try {
      final data = jsonDecode(text);
      if (data is Map && data['code'] is String) {
        final c = (data['code'] as String).toUpperCase();
        if (_codeRe.hasMatch(c)) return c;
      }
    } catch (_) {}
    final up = text.toUpperCase();
    return _codeRe.hasMatch(up) ? up : null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_opening) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final code = _parse(raw);
      if (code != null) {
        _open(code);
        return;
      }
    }
  }

  Future<void> _open(String code) async {
    if (_opening) return;
    _opening = true;
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveViewScreen(pairingCode: code)),
    );
    await _loadLast();
    try {
      await _controller.start();
    } catch (_) {}
    _opening = false;
  }

  Future<void> _enterCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DigiforgeBrand.surface,
      builder: (_) => const _CodeSheet(),
    );
    if (code != null) _open(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Connect to Camera')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Camera access is needed to scan the QR code.\n'
                  'You can still connect by typing the pairing code below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DigiforgeBrand.textSecondary),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan the QR code shown in the Camera app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: DigiforgeBrand.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enterCode,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter pairing code'),
                  ),
                ),
                if (_lastCode != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _open(_lastCode!),
                    icon: const Icon(Icons.history, color: DigiforgeBrand.accent),
                    label: Text('Reconnect to last camera ($_lastCode)',
                        style: const TextStyle(color: DigiforgeBrand.accent)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for typing the 6-character pairing code.
class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final c = _text.text.trim().toUpperCase();
    if (_codeRe.hasMatch(c)) {
      Navigator.pop(context, c);
    } else {
      setState(() => _error = 'Enter all 6 characters of the code shown on the camera phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter pairing code',
              style: TextStyle(
                  color: DigiforgeBrand.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('The 6-character code shown on the camera phone.',
              style: TextStyle(color: DigiforgeBrand.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-HJ-NP-Za-hj-np-z2-9]')),
              _UpperCaseFormatter(),
            ],
            style: const TextStyle(
                color: DigiforgeBrand.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ABC234',
              errorText: _error,
              filled: true,
              fillColor: DigiforgeBrand.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _submit, child: const Text('Connect')),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Cyan corner marks over the scan area.
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DigiforgeBrand.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    final r = size.width;
    final b = size.height;
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);
    canvas.drawLine(Offset(r, 0), Offset(r - len, 0), paint);
    canvas.drawLine(Offset(r, 0), Offset(r, len), paint);
    canvas.drawLine(Offset(0, b), Offset(len, b), paint);
    canvas.drawLine(Offset(0, b), Offset(0, b - len), paint);
    canvas.drawLine(Offset(r, b), Offset(r - len, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - len), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
