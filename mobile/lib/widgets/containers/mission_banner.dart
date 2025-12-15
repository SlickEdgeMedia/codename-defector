import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Banner widget for displaying important messages or alerts.
///
/// Used for error messages, success notifications, or info banners.
class MissionBanner extends StatelessWidget {
  const MissionBanner({
    super.key,
    required this.text,
    this.color = Palette.gold,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}
