import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:imposter_app/constants/avatars.dart';
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

class _ResultsPhaseState extends State<ResultsPhase> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<_LeaderboardEntry> _sortedEntries = [];

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
  void didUpdateWidget(ResultsPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if cumulative scores changed and trigger reorder animation
    final oldResults = oldWidget.state.roundResults;
    final newResults = widget.state.roundResults;

    if (oldResults != null && newResults != null &&
        oldResults.cumulativeScores != newResults.cumulativeScores) {
      _animateLeaderboardChange(oldResults.cumulativeScores, newResults.cumulativeScores);
    }
  }

  void _animateLeaderboardChange(Map<int, int> oldScores, Map<int, int> newScores) {
    // Build sorted lists and animate if order changed
    // This will be called when cumulative scores update
    setState(() {
      // Force rebuild with new order
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  SpyAvatar _getAvatarForParticipant(int participantId) {
    final avatars = SpyAvatar.values;
    return avatars[participantId % avatars.length];
  }

  Widget _buildScoreCard({
    required String name,
    required String subtitle,
    required int score,
    required SpyAvatar avatar,
    required Color scoreColor,
    bool isPositive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar on LEFT
          AvatarIcon(
            avatar: avatar,
            size: 44,
          ),
          const SizedBox(width: 14),
          // Name and Role in MIDDLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Palette.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Score on RIGHT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scoreColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              isPositive && score > 0 ? '+$score' : score.toString(),
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.state.roundResults;
    // Imposter wins if they guessed the word correctly
    final imposterWon = results != null && results.imposterGuessedCorrectly;

    // Build sorted leaderboard for total scores
    List<_LeaderboardEntry> sortedLeaderboard = [];
    if (results != null && results.cumulativeScores.isNotEmpty) {
      sortedLeaderboard = results.scores.map((s) {
        final totalPoints = results.cumulativeScores[s.participantId] ?? 0;
        return _LeaderboardEntry(
          participantId: s.participantId,
          nickname: s.nickname,
          totalPoints: totalPoints,
        );
      }).toList()
        ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints)); // Sort by total points descending
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mission outcome banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: imposterWon
                        ? [Palette.danger.withOpacity(0.2), Palette.danger.withOpacity(0.1)]
                        : [Palette.success.withOpacity(0.2), Palette.success.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: imposterWon ? Palette.danger : Palette.success,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (imposterWon ? Palette.danger : Palette.success).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      imposterWon ? Icons.dangerous : Icons.shield_moon,
                      color: imposterWon ? Palette.danger : Palette.success,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      imposterWon ? 'SPY WINS' : 'CIVILIANS WIN',
                      style: TextStyle(
                        color: imposterWon ? Palette.danger : Palette.success,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Round scores section
              SectionHeader(label: 'This Round'),
              const SizedBox(height: 12),
              if (results == null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Palette.panel.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Palette.stroke.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: Palette.muted, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Awaiting scoring...',
                          style: TextStyle(color: Palette.muted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: results.scores.map((s) {
                    final isPositive = s.points > 0;
                    final scoreColor = isPositive ? Palette.success : Palette.danger;
                    final avatar = _getAvatarForParticipant(s.participantId);
                    return _buildScoreCard(
                      name: s.nickname,
                      subtitle: s.participantId == results.imposterParticipantId ? 'Spy' : 'Civilian',
                      score: s.points,
                      avatar: avatar,
                      scoreColor: scoreColor,
                      isPositive: true,
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              // Total scores section with animated leaderboard
              if (results != null && results.cumulativeScores.isNotEmpty) ...[
                SectionHeader(label: 'Leaderboard'),
                const SizedBox(height: 12),
                // Animated leaderboard
                AnimatedList(
                  key: _listKey,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  initialItemCount: sortedLeaderboard.length,
                  itemBuilder: (context, index, animation) {
                    final entry = sortedLeaderboard[index];
                    final avatar = _getAvatarForParticipant(entry.participantId);

                    return SlideTransition(
                      position: animation.drive(
                        Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeOut)),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: _buildScoreCard(
                          name: entry.nickname,
                          subtitle: 'Total points',
                          score: entry.totalPoints,
                          avatar: avatar,
                          scoreColor: index == 0 ? Palette.gold : Palette.primary,
                          isPositive: false,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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

class _LeaderboardEntry {
  final int participantId;
  final String nickname;
  final int totalPoints;

  _LeaderboardEntry({
    required this.participantId,
    required this.nickname,
    required this.totalPoints,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LeaderboardEntry &&
          runtimeType == other.runtimeType &&
          participantId == other.participantId;

  @override
  int get hashCode => participantId.hashCode;
}
