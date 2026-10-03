import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';

/// Shows this camera's pairing code and QR so a viewer can connect.
class PairingScreen extends StatelessWidget {
  final String code;
  final Future<void> Function() onResetCode;
  const PairingScreen({super.key, required this.code, required this.onResetCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Pair a Viewer')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(data: jsonEncode({'code': code}), size: 220),
              ),
              const SizedBox(height: 24),
              const Text('Scan this QR in the Viewer app,\nor type the code below',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DigiforgeBrand.textSecondary)),
              const SizedBox(height: 12),
              Text(code,
                  style: const TextStyle(
                      color: DigiforgeBrand.accent,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Code copied')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy code'),
              ),
              const SizedBox(height: 24),
              const Text(
                'This code stays the same after restarts so your viewer can\n'
                'reconnect by itself.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await onResetCode();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Generate a new code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
