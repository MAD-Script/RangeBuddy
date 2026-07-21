import 'package:flutter/material.dart';

/// Material 3 theme. Pass through DynamicColorBuilder at the app root
/// (see main.dart) to get true Material You colors pulled from the
/// user's wallpaper on supported Android devices; this seed is the
/// fallback for devices/OS versions that don't support it.
const _seedColor = Color(0xFF00695C); // teal — reads as "energy/electric"

ThemeData buildAppTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = dynamicScheme ??
      ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

/// Semantic colors for the tank gauge, distinct from the app's main
/// color scheme since these carry a fixed meaning (safe/warning/danger)
/// that shouldn't shift with dynamic theming.
class TankColors {
  static const healthy = Color(0xFF00897B);
  static const warning = Color(0xFFFFA000);
  static const danger = Color(0xFFD32F2F);

  static Color forPercent(double percent) {
    if (percent > 40) return healthy;
    if (percent > 15) return warning;
    return danger;
  }
}
