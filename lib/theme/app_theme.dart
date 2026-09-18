import 'package:flutter/material.dart';

/// Material 3 theme with a stable EV-specific palette.
const _seedColor = Color(0xFF168F78);

ThemeData buildAppTheme(ColorScheme? _, Brightness brightness) {
  // Keep the dashboard palette intentional. Dynamic colours are lovely for
  // utility apps, but can turn the teal/blue speed and energy language into
  // arbitrary colours from a device wallpaper.
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
    surface: brightness == Brightness.light
        ? const Color(0xFFF4FAF8)
        : const Color(0xFF101A19),
  );

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
      color: brightness == Brightness.light
          ? const Color(0xFFEAF5F2)
          : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
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
