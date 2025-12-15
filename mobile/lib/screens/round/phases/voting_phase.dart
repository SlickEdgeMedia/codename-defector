import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/headers/section_header.dart';

/// Voting phase widget for identifying the imposter or guessing the word.
class VotingPhase extends StatefulWidget {
  const VotingPhase({
    super.key,
    required this.room,
    required this.state,
    required this.voteTarget,
    required this.onVote,
  });

  final Room room;
  final AppState state;
  final int? voteTarget;
  final void Function(int) onVote;

  @override
  State<VotingPhase> createState() => _VotingPhaseState();
}

class _VotingPhaseState extends State<VotingPhase> {
  int? _selectedWordId;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.state.participant;
    final isImposter = widget.state.roundRole?.role == 'imposter';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImposter) ...[
            SectionHeader(label: 'Spy options'),
            const SizedBox(height: 8),
            const Text(
              'Select the word to win',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 16),
            if (widget.state.roundRole?.wordOptions != null && widget.state.roundRole!.wordOptions!.isNotEmpty)
              Column(
                children: widget.state.roundRole!.wordOptions!.map((wordOption) {
                  final isSelected = _selectedWordId == wordOption.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Palette.gold.withAlpha(20) : Palette.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Palette.gold : Palette.stroke),
                    ),
                    child: ListTile(
                      title: Text(wordOption.text, style: TextStyle(color: isSelected ? Palette.gold : Palette.text)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Palette.gold) : null,
                      onTap: widget.state.guessSubmitted
                          ? null
                          : () => setState(() => _selectedWordId = wordOption.id),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            PrimaryMissionButton(
              label: widget.state.guessSubmitted ? 'Guess submitted' : 'Submit guess',
              onTap: widget.state.guessSubmitted || _selectedWordId == null
                  ? null
                  : () {
                      widget.state.guessWord(wordId: _selectedWordId!);
                    },
            ),
          ] else ...[
            SectionHeader(label: 'Identify the spy'),
            const SizedBox(height: 8),
          ],
          if (!isImposter) ...[
            Column(
              children: widget.room.participants
                  .where((p) => p.id != participant?.id)
                  .map(
                    (p) {
                      final votes = widget.state.voteTotals[p.id] ?? 0;
                      final selected = widget.voteTarget == p.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? Palette.gold.withAlpha(20) : Palette.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? Palette.gold : Palette.stroke),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Palette.gold.withAlpha(40),
                          child: Text(
                            p.nickname.isNotEmpty ? p.nickname.substring(0, 2).toUpperCase() : '?',
                            style: const TextStyle(color: Palette.text),
                          ),
                        ),
                        title: Text(p.nickname),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) const Icon(Icons.check_circle, color: Palette.gold, size: 20),
                            if (!selected) ...[
                              const Icon(Icons.how_to_vote, color: Palette.muted, size: 16),
                              const SizedBox(width: 6),
                              Text(votes.toString()),
                            ],
                          ],
                        ),
                        onTap: widget.state.voted ? null : () => widget.onVote(p.id),
                      ),
                    );
                  },
                )
                .toList(),
            ),
            const SizedBox(height: 12),
            if (!widget.state.voted)
              PrimaryMissionButton(
                label: 'Confirm vote',
                onTap: widget.voteTarget == null
                    ? null
                    : () => widget.state.submitVote(widget.voteTarget!),
              )
            else
              const Text('Vote submitted', style: TextStyle(color: Palette.success)),
          ],
          const SizedBox(height: 12),
          const Text('Tally updates in realtime', style: TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
