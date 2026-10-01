import 'package:flutter/material.dart';

/// DigiforgeDynamics brand tokens — dark theme, single cyan-teal accent.
class DigiforgeBrand {
  DigiforgeBrand._();

  static const Color accent = Color(0xFF00E5C7);
  static const Color accentDim = Color(0xFF0090A8);
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141A21);
  static const Color surfaceAlt = Color(0xFF1C232C);
  static const Color textPrimary = Color(0xFFEAF2F1);
  static const Color textSecondary = Color(0xFF8B97A0);
  static const Color danger = Color(0xFFFF5A5F);

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF04211D),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardColor: surface,
      dividerColor: surfaceAlt,
    );
  }
}
