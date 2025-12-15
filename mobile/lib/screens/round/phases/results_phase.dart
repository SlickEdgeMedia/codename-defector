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
    int? rank,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scoreColor.withOpacity(0.3),
          width: rank == 1 ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(rank == 1 ? 0.2 : 0.1),
            blurRadius: rank == 1 ? 12 : 8,
            spreadRadius: rank == 1 ? 2 : 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge for leaderboard
          if (rank != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: scoreColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  rank == 1 ? '🏆' : '$rank',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w800,
                    fontSize: rank == 1 ? 16 : 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Avatar
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
    final imposterWon = results != null && results.imposterGuessedCorrectly;

    // Find top scorer(s) for this round and their role
    List<String> topScorers = [];
    int maxScore = 0;
    bool topScorerIsSpy = false;
    if (results != null && results.scores.isNotEmpty) {
      maxScore = results.scores.map((s) => s.points).reduce((a, b) => a > b ? a : b);
      final topScorersList = results.scores.where((s) => s.points == maxScore).toList();
      topScorers = topScorersList.map((s) => s.nickname).toList();
      // Check if any top scorer is the spy
      topScorerIsSpy = topScorersList.any((s) => s.participantId == results.imposterParticipantId);
    }

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
        ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mission outcome banner - Show winner(s) with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: topScorerIsSpy
                        ? [Palette.danger.withOpacity(0.2), Palette.danger.withOpacity(0.1)]
                        : [Palette.success.withOpacity(0.2), Palette.success.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: topScorerIsSpy ? Palette.danger : Palette.success,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (topScorerIsSpy ? Palette.danger : Palette.success).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      topScorerIsSpy ? Icons.dangerous : Icons.shield_moon,
                      color: topScorerIsSpy ? Palette.danger : Palette.success,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topScorerIsSpy ? 'SPY' : 'CIVILIAN',
                            style: TextStyle(
                              color: topScorerIsSpy ? Palette.danger : Palette.success,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (topScorers.isNotEmpty)
                            Text(
                              topScorers.length == 1
                                  ? topScorers[0]
                                  : topScorers.join(' & '),
                              style: TextStyle(
                                color: topScorerIsSpy ? Palette.danger : Palette.success,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            maxScore > 0 ? '+$maxScore points' : '$maxScore points',
                            style: TextStyle(
                              color: (topScorerIsSpy ? Palette.danger : Palette.success).withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

              // Total scores section with ranking
              if (results != null && results.cumulativeScores.isNotEmpty) ...[
                SectionHeader(label: 'Leaderboard'),
                const SizedBox(height: 12),
                Column(
                  children: sortedLeaderboard.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leaderboardEntry = entry.value;
                    final rank = index + 1;
                    final avatar = _getAvatarForParticipant(leaderboardEntry.participantId);

                    // Gold for 1st, silver for 2nd, bronze for 3rd, purple for rest
                    Color scoreColor;
                    if (rank == 1) {
                      scoreColor = Palette.gold;
                    } else if (rank == 2) {
                      scoreColor = const Color(0xFFC0C0C0); // Silver
                    } else if (rank == 3) {
                      scoreColor = const Color(0xFFCD7F32); // Bronze
                    } else {
                      scoreColor = Palette.primary;
                    }

                    return _buildScoreCard(
                      name: leaderboardEntry.nickname,
                      subtitle: 'Total points',
                      score: leaderboardEntry.totalPoints,
                      avatar: avatar,
                      scoreColor: scoreColor,
                      isPositive: false,
                      rank: rank,
                    );
                  }).toList(),
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
