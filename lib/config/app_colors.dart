import 'package:flutter/material.dart';

/// Consistent color scheme for the Money Manager app
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF10B981); // Emerald green
  static const Color secondary = Color(0xFFEF4444); // Red
  static const Color tertiary = Color(0xFF8B5CF6); // Purple

  // Background Colors
  static const Color background = Color(0xFF0B0F19); // Dark navy
  static const Color surface = Color(0xFF111827); // Slightly lighter navy
  static const Color surfaceVariant = Color(0xFF1F2937); // Even lighter navy

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFF9CA3AF); // Gray
  static const Color textTertiary = Color(0xFF6B7280); // Darker gray

  // Status Colors
  static const Color success = Color(0xFF10B981); // Green (income)
  static const Color error = Color(0xFFEF4444); // Red (expense)
  static const Color warning = Color(0xFFF59E0B); // Amber (warning)
  static const Color info = Color(0xFF3B82F6); // Blue (info)

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF10B981), // Green
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  // Category Colors (extended palette)
  static const List<Color> categoryColors = [
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFA16207), // Amber-dark
    Color(0xFF7C2D12), // Orange-dark
    Color(0xFF1E3A8A), // Blue-dark
    Color(0xFF1F2937), // Gray-dark
    Color(0xFF7C3AED), // Violet
    Color(0xFF0891B2), // Cyan-dark
    Color(0xFFBE185D), // Pink-dark
    Color(0xFF15803D), // Green-dark
    Color(0xFF0C4A6E), // Blue-darker
    Color(0xFF4C0519), // Red-dark
    Color(0xFF3F0F5C), // Purple-dark
  ];

  /// Get color name from color value
  static String getColorName(Color color) {
    const Map<Color, String> colorNames = {
      Color(0xFF10B981): 'Emerald',
      Color(0xFF3B82F6): 'Blue',
      Color(0xFFF59E0B): 'Amber',
      Color(0xFFEF4444): 'Red',
      Color(0xFF8B5CF6): 'Purple',
      Color(0xFF06B6D4): 'Cyan',
      Color(0xFFEC4899): 'Pink',
      Color(0xFF14B8A6): 'Teal',
      Color(0xFF6366F1): 'Indigo',
      Color(0xFFA16207): 'Amber Dark',
      Color(0xFF7C2D12): 'Orange Dark',
      Color(0xFF1E3A8A): 'Blue Dark',
      Color(0xFF1F2937): 'Gray Dark',
      Color(0xFF7C3AED): 'Violet',
      Color(0xFF0891B2): 'Cyan Dark',
      Color(0xFFBE185D): 'Pink Dark',
      Color(0xFF15803D): 'Green Dark',
      Color(0xFF0C4A6E): 'Blue Darker',
      Color(0xFF4C0519): 'Red Dark',
      Color(0xFF3F0F5C): 'Purple Dark',
    };
    return colorNames[color] ?? 'Custom';
  }
}
