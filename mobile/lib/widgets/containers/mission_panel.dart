import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Container panel with title, optional subtitle, and content.
///
/// Provides consistent styling for grouped content sections.
class MissionPanel extends StatelessWidget {
  const MissionPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Palette.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
