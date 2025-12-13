import 'package:flutter/material.dart';

/// Color palette for The Imposter app theme.
///
/// This defines the dark spy/hacker theme with purple and cyan accents.
class Palette {
  /// Deep dark background color for the app
  static const Color bg = Color(0xFF0F0F1E);

  /// Panel background color (slightly lighter than bg)
  static const Color panel = Color(0xFF1A1A2E);

  /// Primary purple accent color
  static const Color primary = Color(0xFF9D4EDD);

  /// Darker shade of purple for hover/pressed states
  static const Color primaryDark = Color(0xFF7B2CBF);

  /// Bright purple for highlights
  static const Color primaryBright = Color(0xFFC77DFF);

  /// Cyan/teal accent color for highlights and borders
  static const Color accent = Color(0xFF00F5D4);

  /// Darker cyan for secondary accents
  static const Color accentDark = Color(0xFF00D9C0);

  /// Legacy gold color (kept for backwards compatibility, gradually replace with primary)
  static const Color gold = Color(0xFF9D4EDD);

  /// Legacy goldDark (kept for backwards compatibility)
  static const Color goldDark = Color(0xFF7B2CBF);

  /// Primary text color (near white)
  static const Color text = Color(0xFFF5F5F5);

  /// Muted/secondary text color
  static const Color muted = Color(0xFF9EA2AF);

  /// Success/positive state color (green/cyan)
  static const Color success = Color(0xFF00F5D4);

  /// Danger/negative state color (red/pink)
  static const Color danger = Color(0xFFFF006E);

  /// Stroke/border color (lighter for visibility)
  static const Color stroke = Color(0xFF2D2D44);

  /// Glow color for neon effects
  static const Color glow = Color(0xFF00F5D4);
}
