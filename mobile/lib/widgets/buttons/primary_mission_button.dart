import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/utils/haptics.dart';

/// Primary action button with gold background and haptic feedback.
///
/// Used for main CTAs like "Start Mission", "Submit Answer", etc.
class PrimaryMissionButton extends StatelessWidget {
  const PrimaryMissionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap == null ? Palette.goldDark : Palette.gold,
          foregroundColor: Palette.text,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap == null
            ? null
            : () {
                Haptics.medium();
                onTap?.call();
              },
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
