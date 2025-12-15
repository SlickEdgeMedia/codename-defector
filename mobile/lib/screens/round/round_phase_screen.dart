import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/screens/lobby/mission_lobby_screen.dart';
import 'package:imposter_app/screens/round/phases/countdown_phase.dart';
import 'package:imposter_app/screens/round/phases/question_phase.dart';
import 'package:imposter_app/screens/round/phases/results_phase.dart';
import 'package:imposter_app/screens/round/phases/role_phase.dart';
import 'package:imposter_app/screens/round/phases/time_up_phase.dart';
import 'package:imposter_app/screens/round/phases/voting_phase.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/headers/phase_header.dart';
import 'package:imposter_app/widgets/indicators/socket_status_badge.dart';
import 'package:provider/provider.dart';

/// Main round screen that orchestrates different game phases.
///
/// Displays phase-specific UI based on the current round phase.
class RoundPhaseScreen extends StatefulWidget {
  const RoundPhaseScreen({super.key});

  @override
  State<RoundPhaseScreen> createState() => _RoundPhaseScreenState();
}

class _RoundPhaseScreenState extends State<RoundPhaseScreen> {
  int? _voteTarget;
  final _questionText = TextEditingController();
  int? _questionTarget;
  final Map<int, TextEditingController> _answerControllers = {};
  int? _lastQuestionId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = state.roundRole;
    final room = state.room;

    // If no room, go to lobby
    if (room == null) {
      return const MissionLobbyScreen();
    }

    // If we're in an active round but role hasn't loaded yet, show loading
    if (role == null && state.activeRoundId != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Palette.bg,
          elevation: 0,
          title: const Text('LOADING MISSION', style: TextStyle(letterSpacing: 2)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Palette.gold),
        ),
      );
    }

    // If no role and no active round, go to lobby
    if (role == null) {
      return const MissionLobbyScreen();
    }

    if (_lastQuestionId != state.currentQuestionId) {
      _lastQuestionId = state.currentQuestionId;
      _questionText.clear();
      _questionTarget = null;
    }

    // Check if time expired - show Time's Up phase
    if (state.timeExpired) {
      return Scaffold(
        backgroundColor: Palette.bg,
        body: TimeUpPhase(state: state),
      );
    }

    final phase = state.roundPhase;
    final isImposter = role.isImposter;
    final title = () {
      switch (phase) {
        case 'countdown':
          return 'MISSION COUNTDOWN';
        case 'question':
          return 'MISSION QUESTIONS';
        case 'voting':
          return 'MISSION VOTING';
        case 'results':
          return 'MISSION RESULTS';
        default:
          return 'MISSION ROLE';
      }
    }();

    Widget phaseBody;
    switch (phase) {
      case 'countdown':
        phaseBody = CountdownPhase(seconds: state.countdownSeconds);
        break;
      case 'question':
        phaseBody = QuestionPhase(
          room: room,
          state: state,
          questionTarget: _questionTarget,
          onTargetChanged: (id) => setState(() => _questionTarget = id),
          questionText: _questionText,
          answerControllers: _answerControllers,
        );
        break;
      case 'voting':
        phaseBody = VotingPhase(
          room: room,
          state: state,
          voteTarget: _voteTarget,
          onVote: (id) {
            setState(() => _voteTarget = id);
          },
        );
        break;
      case 'results':
        phaseBody = ResultsPhase(state: state);
        break;
      case 'role':
      default:
        phaseBody = RolePhase(role: role, state: state, isImposter: isImposter);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.bg,
        elevation: 0,
        title: Text(title, style: const TextStyle(letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SocketStatusBadge(status: state.socketStatus, error: state.socketError),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoleStrip(
              role: role,
              agentName: state.participant?.nickname ?? state.user?.name ?? '',
            ),
            const SizedBox(height: 8),
            PhaseHeader(
              roundNumber: role.roundNumber,
              code: room.code,
              missionSeconds: state.missionSeconds,
              phase: phase,
            ),
            const SizedBox(height: 12),
            Expanded(child: phaseBody),
          ],
        ),
      ),
    );
  }
}
