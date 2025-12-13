import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/headers/section_header.dart';

/// Results phase widget showing scoring and mission outcome.
class ResultsPhase extends StatelessWidget {
  const ResultsPhase({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final results = state.roundResults;
    // Imposter wins if they guessed the word correctly
    final imposterWon = results != null && results.imposterGuessedCorrectly;

    return SingleChildScrollView(
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
            onTap: () => state.fetchResults(),
          ),
          const SizedBox(height: 8),
          SecondaryMissionButton(
            label: 'Return to lobby',
            onTap: () => state.returnToLobby(),
          ),
        ],
      ),
    );
  }
}
