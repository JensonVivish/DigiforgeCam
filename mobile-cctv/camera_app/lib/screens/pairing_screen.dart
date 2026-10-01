import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_config.dart';
import '../services/signaling_service.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'streaming_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  String? _pairingCode;
  String? _error;
  final _signaling = SignalingService();

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    try {
      final code = await _signaling.createSession();
      if (mounted) setState(() => _pairingCode = code);

      _signaling.onViewerJoined = () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StreamingScreen(
              pairingCode: _pairingCode!,
              signaling: _signaling,
            ),
          ),
        );
      };
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not connect to Firebase.\nCheck internet connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Camera Setup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _pairingCode == null
              ? (_error != null
                  ? Text(_error!,
                      style: const TextStyle(color: DigiforgeBrand.danger),
                      textAlign: TextAlign.center)
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: DigiforgeBrand.accent),
                        SizedBox(height: 16),
                        Text('Connecting to Firebase…',
                            style: TextStyle(color: DigiforgeBrand.textSecondary)),
                      ],
                    ))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                        data: jsonEncode({
                          'code': _pairingCode,
                          'db': AppConfig.firebaseOptions.databaseURL,
                        }),
                        size: 220,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Scan this with the Viewer app',
                        style: TextStyle(color: DigiforgeBrand.textSecondary)),
                    const SizedBox(height: 8),
                    Text(_pairingCode!,
                        style: const TextStyle(
                            color: DigiforgeBrand.accent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6)),
                    const SizedBox(height: 12),
                    const Text(
                      'App will advance automatically when\nviewer scans the code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: DigiforgeBrand.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
