import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Header widget for round phase screens.
///
/// Displays round number, mission timer, and room code.
class PhaseHeader extends StatelessWidget {
  const PhaseHeader({
    super.key,
    required this.roundNumber,
    required this.code,
    required this.missionSeconds,
    required this.phase,
  });

  final int roundNumber;
  final String code;
  final int? missionSeconds;
  final String phase;

  String _format(int? seconds) {
    if (seconds == null || seconds < 0) return '--:--';
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ROUND', style: TextStyle(color: Palette.muted, fontSize: 12)),
            Text(
              roundNumber.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              phase == 'countdown' ? 'MISSION TIMER' : 'TIME LEFT',
              style: const TextStyle(color: Palette.muted, fontSize: 12),
            ),
            Text(
              _format(missionSeconds),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Palette.danger,
                  ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('CODE', style: TextStyle(color: Palette.muted, fontSize: 12)),
            Text(code, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
