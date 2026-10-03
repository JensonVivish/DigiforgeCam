import 'package:flutter/material.dart';

class DF {
  static const bg = Color(0xFF0A0E13);
  static const surface = Color(0xFF121922);
  static const surface2 = Color(0xFF1A2330);
  static const line = Color(0xFF243042);
  static const accent = Color(0xFF19D3C5);
  static const accentSoft = Color(0x2E19D3C5);
  static const accent2 = Color(0xFF22B8F0);
  static const danger = Color(0xFFFF5470);
  static const warn = Color(0xFFFFB84D);
  static const text = Color(0xFFE6EDF5);
  static const muted = Color(0xFF8A97A8);
}

ThemeData dfTheme() {
  const scheme = ColorScheme.dark(
    primary: DF.accent,
    onPrimary: Color(0xFF00201D),
    secondary: DF.accent2,
    surface: DF.surface,
    onSurface: DF.text,
    error: DF.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DF.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: DF.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: DF.surface,
      indicatorColor: DF.accentSoft,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DF.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: DF.text,
        side: const BorderSide(color: DF.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
