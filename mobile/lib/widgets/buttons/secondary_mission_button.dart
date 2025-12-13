import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Secondary action button with gold outline.
///
/// Used for secondary actions like "Cancel", "View History", etc.
class SecondaryMissionButton extends StatelessWidget {
  const SecondaryMissionButton({
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
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Palette.gold, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: Palette.gold,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
