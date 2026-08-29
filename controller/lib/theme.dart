import 'package:flutter/material.dart';

/// RMODZ Remote design system: dark, minimal, glassmorphism, neon purple.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0B12);
  static const Color surface = Color(0xFF14141F);
  static const Color surfaceElevated = Color(0xFF1D1D2B);
  static const Color accent = Color(0xFF9F7AFF); // neon purple
  static const Color accentSoft = Color(0xFFB79CFF);
  static const Color textPrimary = Color(0xFFF2F2F7);
  static const Color textSecondary = Color(0xFF9A9AAF);
  static const Color success = Color(0xFF35E0A1);
  static const Color danger = Color(0xFFFF5378);
  static const Color warning = Color(0xFFFFC24B);
  static const Color online = Color(0xFF35E0A1);
  static const Color offline = Color(0xFF6E6E85);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: accentSoft,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, height: 1.4),
        bodyMedium: TextStyle(color: textSecondary, height: 1.4),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.85),
        indicatorColor: accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: 0.7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.5)),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.06)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : Colors.white.withValues(alpha: 0.15)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  /// Linear gradient used for hero cards / buttons.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF9F7AFF), Color(0xFF6E5BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
