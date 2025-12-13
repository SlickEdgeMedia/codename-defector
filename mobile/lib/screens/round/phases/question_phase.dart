import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/headers/section_header.dart';

/// Question phase widget for asking questions and answering.
class QuestionPhase extends StatelessWidget {
  const QuestionPhase({
    super.key,
    required this.room,
    required this.state,
    required this.questionTarget,
    required this.onTargetChanged,
    required this.questionText,
    required this.answerControllers,
  });

  final Room room;
  final AppState state;
  final int? questionTarget;
  final void Function(int?) onTargetChanged;
  final TextEditingController questionText;
  final Map<int, TextEditingController> answerControllers;

  @override
  Widget build(BuildContext context) {
    final participant = state.participant;
    final askerId = state.currentAskerId;
    final asker = askerId != null
        ? room.participants.firstWhere(
            (p) => p.id == askerId,
            orElse: () => participant ?? room.participants.first,
          )
        : null;
    final isMyTurn = askerId != null && askerId == participant?.id;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: isMyTurn ? 'Your turn to interrogate' : 'Waiting for next agent'),
          const SizedBox(height: 8),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MissionBanner(text: state.errorMessage!, color: Palette.danger),
            ),
          if (!isMyTurn)
            Text(
              asker != null ? 'Agent ${asker.nickname} is asking' : 'Turn order not started',
              style: const TextStyle(color: Palette.muted),
            ),
          if (!isMyTurn) const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: questionTarget,
            hint: const Text('Select target'),
            items: room.participants
                .where((p) => p.id != participant?.id)
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nickname)))
                .toList(),
            onChanged: (!isMyTurn || state.askedQuestion) ? null : onTargetChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: questionText,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Your question'),
            enabled: isMyTurn && !state.askedQuestion,
          ),
          const SizedBox(height: 8),
          PrimaryMissionButton(
            label: state.askedQuestion ? 'Question sent' : 'Submit question',
            onTap: state.askedQuestion || questionTarget == null || !isMyTurn
                ? null
                : () => state.askQuestion(
                      targetId: questionTarget!,
                      text: questionText.text.trim(),
                    ),
          ),
          const SizedBox(height: 20),
          SectionHeader(label: 'My questions'),
          const SizedBox(height: 8),
          if (state.roundQuestions.where((q) => q.askerId == participant?.id && q.answer != null).isEmpty)
            const Text('No answered questions yet.', style: TextStyle(color: Palette.muted))
          else
            Column(
              children: state.roundQuestions
                  .where((q) => q.askerId == participant?.id && q.answer != null)
                  .map((q) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    border: Border.all(color: Palette.gold, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To: ${q.targetName ?? 'Agent'}', style: const TextStyle(color: Palette.gold)),
                      const SizedBox(height: 4),
                      Text('Q: ${q.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('A: ${q.answer}', style: const TextStyle(color: Palette.success)),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          SectionHeader(label: 'Answer queue'),
          const SizedBox(height: 8),
          if (state.pendingQuestions.isEmpty)
            const Text('No pending questions for you.', style: TextStyle(color: Palette.muted))
          else
            Column(
              children: state.pendingQuestions.map((q) {
                final ctrl = answerControllers.putIfAbsent(q.id, () => TextEditingController());
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    border: Border.all(color: Palette.stroke),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${q.askerName ?? 'Agent'}'),
                      const SizedBox(height: 4),
                      Text(q.text),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(labelText: 'Your answer'),
                      ),
                      const SizedBox(height: 6),
                      SecondaryMissionButton(
                        label: 'Submit answer',
                        onTap: () => state.answerQuestion(
                          questionId: q.id,
                          text: ctrl.text.trim(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
