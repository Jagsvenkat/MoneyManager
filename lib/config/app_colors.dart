import 'package:flutter/material.dart';

/// Material 3 inspired color scheme for Money Manager
class AppColors {
  // Material 3 Primary Palette — Emerald Teal
  static const Color primary = Color(0xFF2DD4BF); // Teal 400 — vibrant accent
  static const Color onPrimary = Color(0xFF003731); // Dark teal for contrast
  static const Color primaryContainer = Color(0xFF005048); // Deep teal
  static const Color onPrimaryContainer = Color(0xFF6FEDDA); // Light teal

  // Secondary — Warm Indigo
  static const Color secondary = Color(0xFFA78BFA); // Violet 400
  static const Color onSecondary = Color(0xFF003731);
  static const Color secondaryContainer = Color(0xFF4C1D95); // Deep violet
  static const Color onSecondaryContainer = Color(0xFFD8B4FE); // Light violet

  // Tertiary — Amber Gold
  static const Color tertiary = Color(0xFFFBBF24); // Amber 400
  static const Color onTertiary = Color(0xFF3D2E00);
  static const Color tertiaryContainer = Color(0xFF5C4300);
  static const Color onTertiaryContainer = Color(0xFFFCD34D);

  // Error — Rose/Coral
  static const Color error = Color(0xFFFB7185); // Rose 400
  static const Color onError = Color(0xFF57001A);
  static const Color errorContainer = Color(0xFF80002A);
  static const Color onErrorContainer = Color(0xFFFEA3B4);

  // Surface / Background — Neutral Dark
  static const Color background = Color(0xFF0F1115); // Dark neutral
  static const Color onBackground = Color(0xFFE2E8F0);
  static const Color surface = Color(0xFF161A22); // Elevated surface
  static const Color onSurface = Color(0xFFE2E8F0);
  static const Color surfaceVariant = Color(0xFF1E2430); // Card surface
  static const Color onSurfaceVariant = Color(0xFF94A3B8);
  static const Color outline = Color(0xFF2D3545);
  static const Color outlineVariant = Color(0xFF1E2430);

  // Status Colors (semantic)
  static const Color success = Color(0xFF34D399); // Emerald 400
  static const Color warning = Color(0xFFFBBF24); // Amber 400
  static const Color info = Color(0xFF60A5FA); // Blue 400

  // Legacy aliases for backward compatibility
  static const Color textPrimary = onBackground;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = Color(0xFF64748B); // Slate 500

  // Chart Colors — Material 3 extended palette
  static const List<Color> chartColors = [
    Color(0xFF2DD4BF), // Teal 400
    Color(0xFFA78BFA), // Violet 400
    Color(0xFFFBBF24), // Amber 400
    Color(0xFFFB7185), // Rose 400
    Color(0xFF60A5FA), // Blue 400
    Color(0xFF34D399), // Emerald 400
    Color(0xFFF472B6), // Pink 400
    Color(0xFF22D3EE), // Cyan 400
  ];

  // Category Colors — extended palette (20 colors)
  static const List<Color> categoryColors = [
    Color(0xFF2DD4BF), // Teal
    Color(0xFF60A5FA), // Blue
    Color(0xFFFBBF24), // Amber
    Color(0xFFFB7185), // Rose
    Color(0xFFA78BFA), // Violet
    Color(0xFF22D3EE), // Cyan
    Color(0xFFF472B6), // Pink
    Color(0xFF34D399), // Emerald
    Color(0xFF818CF8), // Indigo
    Color(0xFFF59E0B), // Amber-dark
    Color(0xFFFB923C), // Orange
    Color(0xFF3B82F6), // Blue-500
    Color(0xFF64748B), // Slate
    Color(0xFFC084FC), // Purple
    Color(0xFF06B6D4), // Cyan-dark
    Color(0xFFE879F9), // Fuchsia
    Color(0xFF10B981), // Green
    Color(0xFF0284C7), // Sky
    Color(0xFFBE123C), // Rose-dark
    Color(0xFF7C3AED), // Violet-dark
  ];

  /// Get color name from color value
  static String getColorName(Color color) {
    final Map<Color, String> colorNames = {
      Color(0xFF2DD4BF): 'Teal',
      Color(0xFF60A5FA): 'Blue',
      Color(0xFFFBBF24): 'Amber',
      Color(0xFFFB7185): 'Rose',
      Color(0xFFA78BFA): 'Violet',
      Color(0xFF22D3EE): 'Cyan',
      Color(0xFFF472B6): 'Pink',
      Color(0xFF34D399): 'Emerald',
      Color(0xFF818CF8): 'Indigo',
      Color(0xFFF59E0B): 'Amber Dark',
      Color(0xFFFB923C): 'Orange',
      Color(0xFF3B82F6): 'Blue 500',
      Color(0xFF64748B): 'Slate',
      Color(0xFFC084FC): 'Purple',
      Color(0xFF06B6D4): 'Cyan Dark',
      Color(0xFFE879F9): 'Fuchsia',
      Color(0xFF10B981): 'Green',
      Color(0xFF0284C7): 'Sky',
      Color(0xFFBE123C): 'Rose Dark',
      Color(0xFF7C3AED): 'Violet Dark',
    };
    return colorNames[color] ?? 'Custom';
  }
}
