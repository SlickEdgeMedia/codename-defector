import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';

/// Countdown phase widget showing mission start countdown with animations.
class CountdownPhase extends StatefulWidget {
  const CountdownPhase({super.key, required this.seconds});

  final int seconds;

  @override
  State<CountdownPhase> createState() => _CountdownPhaseState();
}

class _CountdownPhaseState extends State<CountdownPhase> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(CountdownPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('MISSION COMMENCING', style: TextStyle(color: Palette.muted, letterSpacing: 2)),
                  const SizedBox(height: 24),
                  // Pulsing circle background
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Palette.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.primary.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.seconds.clamp(0, 99).toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Palette.primaryBright,
                              fontWeight: FontWeight.w800,
                              fontSize: 72,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Prepare for deployment', style: TextStyle(color: Palette.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
