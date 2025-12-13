import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Countdown phase widget showing mission start countdown.
class CountdownPhase extends StatelessWidget {
  const CountdownPhase({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('MISSION COMMENCING', style: TextStyle(color: Palette.muted, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(
            seconds.clamp(0, 99).toString(),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          const Text('Prepare for deployment', style: TextStyle(color: Palette.muted)),
        ],
      ),
    );
  }
}
