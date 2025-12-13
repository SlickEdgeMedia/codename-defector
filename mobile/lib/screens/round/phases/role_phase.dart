import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/models/round_models.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/containers/mission_card.dart';

/// Role strip widget showing agent name and role.
class RoleStrip extends StatelessWidget {
  const RoleStrip({super.key, required this.role, required this.agentName});

  final RoundRoleInfo role;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final isImposter = role.isImposter;
    final accent = isImposter ? Palette.danger : Palette.success;
    final subtitle = isImposter
        ? 'Blend in and identify the word'
        : (role.word != null ? 'Word: ${role.word}' : 'Civilian');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.stroke),
      ),
      child: Row(
        children: [
          Icon(isImposter ? Icons.visibility_off : Icons.shield_moon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AGENT: ${agentName.isNotEmpty ? agentName : 'UNKNOWN'}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  isImposter ? 'SPY' : 'CIVILIAN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Role phase widget showing assigned role and word/word options.
class RolePhase extends StatelessWidget {
  const RolePhase({
    super.key,
    required this.role,
    required this.state,
    required this.isImposter,
  });

  final RoundRoleInfo role;
  final AppState state;
  final bool isImposter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isImposter ? 'SPY' : 'CIVILIAN',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isImposter ? Palette.danger : Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('Category: ${role.category}', style: const TextStyle(color: Palette.muted)),
          const SizedBox(height: 24),
          if (!isImposter)
            MissionCard(
              title: 'CLASSIFIED WORD',
              value: role.word ?? 'Unknown',
              actionLabel: 'Conceal word',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('POSSIBLE TARGETS', style: TextStyle(color: Palette.muted)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                    ),
                    itemCount: role.wordOptions.length,
                    itemBuilder: (context, index) {
                      final w = role.wordOptions[index];
                      final crossed = state.crossedWords.contains(w.text);
                      return GestureDetector(
                        onTap: () => state.toggleCrossedWord(w.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Palette.stroke,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: crossed ? Palette.danger : Palette.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.text,
                                  style: TextStyle(
                                    decoration: crossed ? TextDecoration.lineThrough : TextDecoration.none,
                                    color: crossed ? Palette.muted : Palette.text,
                                  ),
                                ),
                              ),
                              if (crossed)
                                const Icon(Icons.close, size: 16, color: Palette.danger),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
