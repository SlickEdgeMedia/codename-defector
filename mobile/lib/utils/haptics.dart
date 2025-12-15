import 'package:flutter/services.dart';

/// Haptic feedback utilities for better user experience.
class Haptics {
  /// Light impact haptic (for taps, selections)
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact haptic (for confirmations, submissions)
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact haptic (for important actions, errors)
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection haptic (for toggles, switches)
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Success haptic pattern
  static void success() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Error haptic pattern
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.heavyImpact();
    });
  }
}
