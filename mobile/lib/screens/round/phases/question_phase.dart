import 'package:flutter/material.dart';
import 'package:imposter_app/constants/avatars.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/models/round_models.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/headers/section_header.dart';

/// Question phase widget for asking questions and answering.
class QuestionPhase extends StatefulWidget {
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
  State<QuestionPhase> createState() => _QuestionPhaseState();
}

class _QuestionPhaseState extends State<QuestionPhase> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  SpyAvatar _getAvatarForParticipant(int participantId) {
    final avatars = SpyAvatar.values;
    return avatars[participantId % avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.state.participant;
    final askerId = widget.state.currentAskerId;
    final asker = askerId != null
        ? widget.room.participants.firstWhere(
            (p) => p.id == askerId,
            orElse: () => participant ?? widget.room.participants.first,
          )
        : null;
    final isMyTurn = askerId != null && askerId == participant?.id;

    // Find who is currently answering (target of current question)
    RoundQuestionItem? currentQuestion;
    try {
      currentQuestion = widget.state.roundQuestions.firstWhere(
        (q) => q.id == widget.state.currentQuestionId,
      );
    } catch (e) {
      // Question not found, that's okay
      currentQuestion = null;
    }
    final answererId = currentQuestion?.targetId;
    final answerer = answererId != null
        ? widget.room.participants.firstWhere(
            (p) => p.id == answererId,
            orElse: () => participant ?? widget.room.participants.first,
          )
        : null;
    final isMyAnsweringTurn = answererId != null && answererId == participant?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn indicator banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMyTurn
                    ? [Palette.primary.withOpacity(0.3), Palette.primaryBright.withOpacity(0.2)]
                    : [Palette.panel, Palette.bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMyTurn ? Palette.primary : Palette.stroke,
                width: isMyTurn ? 2 : 1,
              ),
              boxShadow: isMyTurn
                  ? [
                      BoxShadow(
                        color: Palette.primary.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (asker != null)
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: AvatarIcon(
                      avatar: _getAvatarForParticipant(asker.id),
                      size: 48,
                      selected: isMyTurn,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMyTurn ? 'YOUR TURN' : 'STANDBY',
                        style: TextStyle(
                          color: isMyTurn ? Palette.primaryBright : Palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.state.turnTimedOut && isMyTurn
                            ? widget.state.isAskingPhase
                                ? 'Failed to ask question in time'
                                : 'Waiting for answer...'
                            : widget.state.turnTimedOut && !isMyTurn && widget.state.isAskingPhase
                                ? '${asker?.nickname ?? 'Agent'} timed out'
                                : widget.state.turnTimedOut && !isMyTurn && !widget.state.isAskingPhase
                                    ? 'Answering agent timed out'
                                    : isMyTurn
                                        ? 'Interrogate an agent'
                                        : !widget.state.isAskingPhase && isMyAnsweringTurn
                                            ? 'Your turn to answer'
                                            : !widget.state.isAskingPhase && answerer != null
                                                ? '${answerer.nickname} is answering'
                                                : asker != null
                                                    ? '${asker.nickname} is interrogating'
                                                    : 'Waiting for game to start',
                        style: TextStyle(
                          color: widget.state.turnTimedOut
                              ? Palette.danger
                              : isMyTurn
                                  ? Palette.text
                                  : Palette.muted,
                          fontWeight: isMyTurn || widget.state.turnTimedOut ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      // Show asking/answering phase indicator
                      if (widget.state.turnSeconds != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.state.isAskingPhase ? 'Asking phase' : 'Answering phase',
                          style: TextStyle(
                            color: widget.state.turnSeconds! <= 10 ? Palette.danger : Palette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Turn timer display
                if (widget.state.turnSeconds != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.state.turnSeconds! <= 10
                          ? Palette.danger.withOpacity(0.2)
                          : Palette.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.state.turnSeconds! <= 10 ? Palette.danger : Palette.primary,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          color: widget.state.turnSeconds! <= 10 ? Palette.danger : Palette.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.state.turnSeconds}s',
                          style: TextStyle(
                            color: widget.state.turnSeconds! <= 10 ? Palette.danger : Palette.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isMyTurn)
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Icon(
                      Icons.radio_button_checked,
                      color: Palette.primary,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error message
          if (widget.state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MissionBanner(text: widget.state.errorMessage!, color: Palette.danger),
            ),

          // Ask question section
          if (isMyTurn || widget.questionTarget != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isMyTurn ? Palette.accent.withOpacity(0.5) : Palette.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_search, color: Palette.accent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'SELECT TARGET',
                        style: TextStyle(
                          color: Palette.muted,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: widget.questionTarget,
                    hint: const Text('Choose an agent to question'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Palette.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.accent, width: 2),
                      ),
                    ),
                    items: widget.room.participants
                        .where((p) => p.id != participant?.id)
                        .map((p) {
                      final avatar = _getAvatarForParticipant(p.id);
                      return DropdownMenuItem(
                        value: p.id,
                        child: Row(
                          children: [
                            AvatarIcon(avatar: avatar, size: 24),
                            const SizedBox(width: 12),
                            Text(p.nickname),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (!isMyTurn || widget.state.askedQuestion) ? null : widget.onTargetChanged,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: Palette.accent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'YOUR QUESTION',
                        style: TextStyle(
                          color: Palette.muted,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: widget.questionText,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter your interrogation question...',
                      hintStyle: TextStyle(color: Palette.muted.withOpacity(0.5)),
                      filled: true,
                      fillColor: Palette.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Palette.accent, width: 2),
                      ),
                    ),
                    enabled: isMyTurn && !widget.state.askedQuestion,
                  ),
                  const SizedBox(height: 16),
                  PrimaryMissionButton(
                    label: widget.state.turnTimedOut && widget.state.isAskingPhase
                        ? 'Time expired'
                        : widget.state.askedQuestion
                            ? 'Question sent'
                            : 'Submit question',
                    onTap: widget.state.askedQuestion ||
                            widget.questionTarget == null ||
                            !isMyTurn ||
                            widget.state.turnTimedOut
                        ? null
                        : () => widget.state.askQuestion(
                              targetId: widget.questionTarget!,
                              text: widget.questionText.text.trim(),
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Answer queue section
          SectionHeader(label: 'Pending answers'),
          const SizedBox(height: 12),
          if (widget.state.pendingQuestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Palette.panel.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.stroke.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Palette.muted, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No pending questions for you',
                      style: TextStyle(color: Palette.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: widget.state.pendingQuestions.map((q) {
                final ctrl = widget.answerControllers.putIfAbsent(q.id, () => TextEditingController());
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.danger.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.danger.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.priority_high, color: Palette.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'FROM: ${q.askerName?.toUpperCase() ?? 'AGENT'}',
                              style: const TextStyle(
                                color: Palette.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Palette.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          q.text,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: 'Type your response...',
                          hintStyle: TextStyle(color: Palette.muted.withOpacity(0.5)),
                          filled: true,
                          fillColor: Palette.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Palette.stroke),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Palette.stroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Palette.accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryMissionButton(
                        label: widget.state.turnTimedOut && !widget.state.isAskingPhase && q.id == widget.state.currentQuestionId
                            ? 'Time expired'
                            : 'Submit answer',
                        onTap: widget.state.turnTimedOut && !widget.state.isAskingPhase && q.id == widget.state.currentQuestionId
                            ? null
                            : () => widget.state.answerQuestion(
                                  questionId: q.id,
                                  text: ctrl.text.trim(),
                                ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Answered questions section
          SectionHeader(label: 'My intel'),
          const SizedBox(height: 12),
          if (widget.state.roundQuestions.where((q) => q.askerId == participant?.id && q.answer != null).isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Palette.panel.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.stroke.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: Palette.muted, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No answered questions yet',
                      style: TextStyle(color: Palette.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: widget.state.roundQuestions
                  .where((q) => q.askerId == participant?.id && q.answer != null)
                  .map((q) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.accent.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.accent.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Palette.accent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'TO: ${q.targetName?.toUpperCase() ?? 'AGENT'}',
                            style: const TextStyle(
                              color: Palette.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Q:', style: TextStyle(color: Palette.muted, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q.text,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Palette.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Palette.success.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('A:', style: TextStyle(color: Palette.success, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.answer ?? '',
                                style: TextStyle(color: Palette.success, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
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
