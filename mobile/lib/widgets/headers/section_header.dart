import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Section header widget for labeling content sections.
///
/// Displays muted, uppercase text with letter spacing.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        letterSpacing: 1.5,
        color: Palette.muted,
      ),
    );
  }
}
