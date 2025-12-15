import 'dart:async';
import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';

/// Time's Up phase widget shown when round timer expires.
///
/// Displays for 3 seconds showing who didn't participate, then auto-transitions to voting.
class TimeUpPhase extends StatefulWidget {
  const TimeUpPhase({super.key, required this.state});

  final AppState state;

  @override
  State<TimeUpPhase> createState() => _TimeUpPhaseState();
}

class _TimeUpPhaseState extends State<TimeUpPhase> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _countdown = 3;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start countdown timer
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown -= 1;
        });
      } else {
        timer.cancel();
        // Auto-transition to voting
        widget.state.proceedToVoting();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactivePlayers = widget.state.getInactivePlayers();

    return Container(
      color: Palette.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing clock icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Palette.danger.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Palette.danger,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.danger.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm_off,
                    color: Palette.danger,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // TIME'S UP text
              const Text(
                "TIME'S UP",
                style: TextStyle(
                  color: Palette.danger,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),

              // Countdown to voting
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Palette.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.danger.withOpacity(0.5)),
                ),
                child: Text(
                  'Proceeding to voting in $_countdown...',
                  style: const TextStyle(
                    color: Palette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Show inactive players if any
              if (inactivePlayers.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Palette.danger.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            color: Palette.danger.withOpacity(0.7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'INACTIVE AGENTS',
                            style: TextStyle(
                              color: Palette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inactivePlayers.join(', '),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Palette.danger.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        inactivePlayers.length == 1
                            ? 'Did not participate'
                            : 'Did not participate',
                        style: TextStyle(
                          color: Palette.muted.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Palette.success.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Palette.success.withOpacity(0.7),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All agents participated',
                        style: TextStyle(
                          color: Palette.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
