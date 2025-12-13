import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/headers/section_header.dart';

/// Results phase widget showing scoring and mission outcome with celebration.
class ResultsPhase extends StatefulWidget {
  const ResultsPhase({super.key, required this.state});

  final AppState state;

  @override
  State<ResultsPhase> createState() => _ResultsPhaseState();
}

class _ResultsPhaseState extends State<ResultsPhase> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    // Start confetti on load
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.state.roundResults;
    // Imposter wins if they guessed the word correctly
    final imposterWon = results != null && results.imposterGuessedCorrectly;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Mission outcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: imposterWon ? Palette.danger.withAlpha(26) : Palette.success.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: imposterWon ? Palette.danger : Palette.success,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  imposterWon ? Icons.dangerous : Icons.shield_moon,
                  color: imposterWon ? Palette.danger : Palette.success,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  imposterWon ? 'SPY WINS' : 'CIVILIANS WIN',
                  style: TextStyle(
                    color: imposterWon ? Palette.danger : Palette.success,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Round scores section
          SectionHeader(label: 'This Round'),
          const SizedBox(height: 8),
          if (results == null)
            const Text('Awaiting scoring...', style: TextStyle(color: Palette.muted))
          else
            Column(
              children: results.scores
                  .map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: s.points > 0
                            ? Palette.success.withAlpha(51)
                            : Palette.danger.withAlpha(51),
                        child: Text(
                          s.points > 0 ? '+${s.points}' : s.points.toString(),
                          style: TextStyle(
                            color: s.points > 0 ? Palette.success : Palette.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(s.nickname),
                      subtitle: Text(
                        s.participantId == results.imposterParticipantId
                            ? 'Spy'
                            : 'Civilian',
                        style: const TextStyle(color: Palette.muted),
                      ),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 16),

          // Total scores section
          if (results != null && results.cumulativeScores.isNotEmpty) ...[
            SectionHeader(label: 'Total Scores'),
            const SizedBox(height: 8),
            Column(
              children: results.scores
                  .map((s) {
                    final totalPoints = results.cumulativeScores[s.participantId] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Palette.gold.withAlpha(51),
                        child: Text(
                          totalPoints.toString(),
                          style: const TextStyle(
                            color: Palette.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(s.nickname),
                      subtitle: const Text('Total points', style: TextStyle(color: Palette.muted)),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          SecondaryMissionButton(
            label: 'Refresh results',
            onTap: () => widget.state.fetchResults(),
          ),
          const SizedBox(height: 8),
          SecondaryMissionButton(
            label: 'Return to lobby',
            onTap: () => widget.state.returnToLobby(),
          ),
            ],
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              Palette.primary,
              Palette.primaryBright,
              Palette.accent,
              Palette.accentDark,
              Palette.danger,
            ],
          ),
        ),
      ],
    );
  }
}
