import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/utils/haptics.dart';

/// Primary action button with purple background and haptic feedback.
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Palette.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: onTap == null ? Palette.primaryDark : Palette.primary,
            foregroundColor: Palette.text,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: onTap == null
              ? null
              : () {
                  Haptics.medium();
                  onTap?.call();
                },
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
