import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Card widget for displaying a title, value, and action label.
///
/// Used in lobby/room screens to show key information like room code, duration, etc.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.title,
    required this.value,
    required this.actionLabel,
  });

  final String title;
  final String value;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Palette.accent.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Palette.muted)),
          const SizedBox(height: 8),
          Text(
            value.toUpperCase(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Palette.accent,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 10),
          Text(actionLabel, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
