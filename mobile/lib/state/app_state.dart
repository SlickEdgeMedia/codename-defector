import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imposter_app/constants/game_constants.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/data/round_repository.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/models/round_models.dart';
import 'package:imposter_app/models/user.dart';
import 'package:imposter_app/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main application state manager.
///
/// Manages authentication, room/lobby state, round gameplay, and WebSocket connections.
/// Uses Provider's ChangeNotifier pattern to notify UI of state changes.
class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.roomRepository,
    required this.roundRepository,
    required this.socketService,
    required this.prefs,
  });

  // ============================================================================
  // Dependencies
  // ============================================================================

  final AuthRepository authRepository;
  final RoomRepository roomRepository;
  final RoundRepository roundRepository;
  final SocketService socketService;
  final SharedPreferences prefs;

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Only ensure timer if not already in the process (prevent re-entry)
    if (!_isEnsuring) {
      _ensureTurnTimerRunning();
    }
  }

  // ============================================================================
  // Authentication State
  // ============================================================================

  bool loading = false;
  String? token;
  UserProfile? user;
  String? guestNickname;

  // ============================================================================
  // Room/Lobby State
  // ============================================================================

  Room? room;
  RoomParticipant? participant;
  String? errorMessage;
  String? bannerMessage;

  // ============================================================================
  // WebSocket State
  // ============================================================================

  String socketStatus = SocketStatus.disconnected;
  String? socketError;
  String? socketRoomCode;
  List<String> eventLog = [];

  // ============================================================================
  // Round State
  // ============================================================================

  bool roundLoading = false;
  int? activeRoundId;
  String? activeRoundStatus;
  RoundRoleInfo? roundRole;
  RoundResults? roundResults;
  int? resultsRoundId; // Track which round results are being shown
  bool showRound = true;

  // Round Phase Management
  String roundPhase = GamePhases.role;
  int countdownSeconds = TimingDefaults.countdownSeconds;
  String? _pendingPhaseAfterCountdown;

  // Question/Answer State
  List<RoundQuestionItem> roundQuestions = [];
  int? currentQuestionId;
  int? currentAskerId;
  bool askedQuestion = false;

  // Per-turn timers
  int? turnSeconds; // Seconds remaining for current turn
  bool isAskingPhase = true; // true = asking, false = answering
  Timer? _turnTimer;
  bool turnTimedOut = false; // Track if current turn timed out
  bool _isEnsuring = false; // Re-entry guard for _ensureTurnTimerRunning

  // Voting State
  Map<int, int> voteTotals = {};
  bool voted = false;
  bool readyForVoting = false;
  int readyForVotingCount = 0;
  bool allQuestionsAnswered = false;

  // Imposter State
  bool guessSubmitted = false;
  Set<String> crossedWords = {};
  Map<int, String> notes = {};

  // ============================================================================
  // Timers
  // ============================================================================

  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _missionTimer;
  int? missionSeconds;
  DateTime? missionStart;
  bool timeExpired = false;
  bool _timeExpiredHandled = false;

  // ============================================================================
  // Authentication Methods
  // ============================================================================

  /// Initialize app state from persisted token.
  Future<void> bootstrap() async {
    final savedToken = prefs.getString('auth_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      await _setToken(savedToken, persist: false);
      await refreshSession();
    }
  }

  /// Refresh user session from server.
  Future<void> refreshSession() async {
    if (token == null) return;
    try {
      loading = true;
      notifyListeners();

      final result = await authRepository.introspect();
      user = result.user;
      guestNickname = result.guestNickname;
    } catch (_) {
      await logout();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Register a new user account.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _runGuarded(() async {
      final result = await authRepository.register(
        name: name,
        email: email,
        password: password,
      );
      await _setToken(result.token);
      user = result.user;
    }, fallbackMessage: 'Registration failed');
  }

  Future<void> login({required String email, required String password}) async {
    await _runGuarded(() async {
      final result = await authRepository.login(
        email: email,
        password: password,
      );
      await _setToken(result.token);
      user = result.user;
      guestNickname = null;
    }, fallbackMessage: 'Login failed');
  }

  Future<void> guestLogin({required String nickname}) async {
    await _runGuarded(() async {
      final result = await authRepository.guest(nickname: nickname);
      await _setToken(result.token);
      user = null;
      guestNickname = result.guestNickname;
    }, fallbackMessage: 'Guest login failed');
  }

  Future<void> logout() async {
    token = null;
    user = null;
    guestNickname = null;
    room = null;
    participant = null;
    _resetRoundState();
    socketStatus = 'disconnected';
    socketError = null;
    socketService.disconnect();
    socketRoomCode = null;
    _stopPolling();
    showRound = true;
    roundPhase = 'role';
    _stopCountdown();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  // ============================================================================
  // Room/Lobby Methods
  // ============================================================================

  /// Create a new room and join as host.
  Future<void> createRoom({
    required String nickname,
    required String category,
    required int roundDurationSeconds,
    int? maxPlayers,
  }) async {
    if (token == null) return;
    await _runGuarded(() async {
      final session = await roomRepository.createRoom(
        nickname: nickname,
        category: category,
        roundDurationSeconds: roundDurationSeconds,
        maxPlayers: maxPlayers,
      );
      _setRoomSession(session);
    }, fallbackMessage: 'Failed to create room');
  }

  Future<void> joinRoom({
    required String code,
    required String nickname,
  }) async {
    if (token == null) return;
    await _runGuarded(() async {
      final session = await roomRepository.joinRoom(
        code: code,
        nickname: nickname,
      );
      _setRoomSession(session);
    }, fallbackMessage: 'Failed to join room');
  }

  Future<void> setReady(bool ready) async {
    if (room == null || token == null) return;
    await _runGuarded(
      () async {
        final session = await roomRepository.setReady(
          code: room!.code,
          ready: ready,
        );
        _setRoomSession(session);
      },
      fallbackMessage: 'Failed to update ready state',
      setLoading: false,
    );
  }

  Future<void> leaveRoom() async {
    if (room == null || token == null) return;
    await _runGuarded(() async {
      await roomRepository.leaveRoom(room!.code);
      room = null;
      participant = null;
      _resetRoundState();
      socketService.disconnect();
      socketRoomCode = null;
      _stopPolling();
      showRound = true;
      roundPhase = 'role';
      _stopCountdown();
    }, fallbackMessage: 'Failed to leave room');
  }

  Future<void> refreshRoom() async {
    if (room == null) return;
    try {
      final latest = await roomRepository.fetchRoom(room!.code);
      _syncRoom(latest);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> backToLobby() async {
    activeRoundId = null;
    activeRoundStatus = null;
    roundRole = null;
    roundResults = null;
    roundQuestions = [];
    voteTotals = {};
    showRound = false;
    roundPhase = GamePhases.role;
    notifyListeners();
    await refreshRoom();
  }

  // ============================================================================
  // Round Methods
  // ============================================================================

  /// Start a new round (host only).
  Future<void> startRound() async {
    if (room == null) return;
    await _runGuarded(() async {
      final roundStart = await roundRepository.startRound(room!.code);
      final roundId = roundStart.roundId;
      if (roundId <= 0) {
        throw Exception('Invalid round start response');
      }
      final countdownTotal = roundStart.countdownSeconds ?? room!.countdownSeconds;
      final duration = roundStart.roundDurationSeconds ?? room!.roundDurationSeconds;
      final startedAt = roundStart.startedAt ?? DateTime.now();
      _resetRoundState(roundId: roundId, status: 'in_progress');
      showRound = true;
      currentAskerId = roundStart.firstAskerId;
      currentQuestionId = roundStart.firstQuestionId;
      if (roundStart.firstQuestionId != null) {
        _pendingPhaseAfterCountdown = 'question';
      }
      final missionStartTime = startedAt.add(Duration(seconds: countdownTotal));
      missionStart = missionStartTime;
      missionSeconds = _computeRemaining(duration, missionStartTime);
      _startMissionTimer(duration, missionStartTime);
      _startCountdown(countdownTotal, onFinished: () {
        roundPhase = _pendingPhaseAfterCountdown ?? 'role';
        _pendingPhaseAfterCountdown = null;
        // Start turn timer when countdown finishes and we have a first asker
        if (currentAskerId != null && roundPhase == 'question') {
          _startTurnTimer(isAsking: true);
        }
        notifyListeners();
      });
      loadRoundRole(roundId);
      await refreshRoom();
    }, fallbackMessage: 'Could not start round');
  }

  Future<void> loadRoundRole([int? roundId]) async {
    if (roundId == null) return;
    try {
      roundLoading = true;
      notifyListeners();
      final role = await roundRepository.fetchRole(roundId);
      roundRole = role;
      crossedWords = {};
      showRound = true;
      // role arriving doesn't end countdown; countdown timer will flip phase when done
    } catch (_) {
      // ignore fetch issues silently, UI will keep retry options
    } finally {
      roundLoading = false;
      notifyListeners();
    }
  }

  Future<void> askQuestion({
    required int targetId,
    required String text,
  }) async {
    if (activeRoundId == null || participant == null) return;

    await _runGuarded(() async {
      final question = await roundRepository.askQuestion(
        roundId: activeRoundId!,
        targetId: targetId,
        text: text,
        askerId: participant!.id,
        askerName: participant?.nickname,
        targetName: room?.participants
            .firstWhere((p) => p.id == targetId, orElse: () => participant!)
            .nickname,
      );
      askedQuestion = true;
      currentQuestionId = question.id;
      currentAskerId = question.askerId;
      _upsertQuestion(question.copyWith(answer: null));
    }, fallbackMessage: 'Could not send question', setLoading: false);
  }

  Future<void> answerQuestion({
    required int questionId,
    required String text,
  }) async {
    if (activeRoundId == null) return;
    await _runGuarded(() async {
      await roundRepository.answerQuestion(
        roundId: activeRoundId!,
        questionId: questionId,
        text: text,
      );
      _markAnswer(questionId, text);
    }, fallbackMessage: 'Could not submit answer', setLoading: false);
  }

  Future<void> submitVote(int targetId) async {
    if (activeRoundId == null) return;
    await _runGuarded(() async {
      await roundRepository.vote(roundId: activeRoundId!, targetId: targetId);
      voted = true;
    }, fallbackMessage: 'Vote failed', setLoading: false);
  }

  Future<void> guessWord({required int wordId}) async {
    if (activeRoundId == null) {
      return;
    }
    await _runGuarded(() async {
      await roundRepository.imposterGuess(roundId: activeRoundId!, wordId: wordId);
      guessSubmitted = true;
    }, fallbackMessage: 'Guess failed', setLoading: false);
  }

  Future<void> skipVote() async {
    if (activeRoundId == null) {
      return;
    }
    await _runGuarded(() async {
      await roundRepository.skipGuess(roundId: activeRoundId!);
      voted = true;
      guessSubmitted = true;
    }, fallbackMessage: 'Skip failed', setLoading: false);
  }

  Future<void> markReadyForVoting() async {
    if (activeRoundId == null) return;
    await _runGuarded(() async {
      await roundRepository.markReadyForVoting(roundId: activeRoundId!);
      readyForVoting = true;
    }, fallbackMessage: 'Could not mark ready', setLoading: false);
  }

  Future<void> submitGuess(int wordId) async {
    if (activeRoundId == null) return;
    await _runGuarded(() async {
      await roundRepository.imposterGuess(
        roundId: activeRoundId!,
        wordId: wordId,
      );
      guessSubmitted = true;
    }, fallbackMessage: 'Guess failed', setLoading: false);
  }

  Future<void> fetchResults([int? roundId]) async {
    // Use provided roundId, or fallback to resultsRoundId (for refresh), or activeRoundId
    final id = roundId ?? resultsRoundId ?? activeRoundId;
    if (id == null) {
      return;
    }
    try {
      roundResults = await roundRepository.fetchResults(id);
      resultsRoundId = id; // Remember which round results we're showing
      notifyListeners();
    } catch (e, stackTrace) {
      // Error fetching results
    }
  }

  void returnToLobby() {
    showRound = false;
    roundPhase = 'role';
    resultsRoundId = null;
    errorMessage = null; // Clear any errors when returning to lobby
    notifyListeners();
  }

    List<RoundQuestionItem> get pendingQuestions {
    if (participant == null) return [];
    return roundQuestions
        .where((q) => q.targetId == participant!.id && q.answer == null && q.text.trim().isNotEmpty)
        .toList();
  }

  void updateNote(int participantId, String value) {
    notes = {...notes, participantId: value};
    notifyListeners();
  }

  void toggleCrossedWord(String word) {
    final updated = Set<String>.from(crossedWords);
    if (updated.contains(word)) {
      updated.remove(word);
    } else {
      updated.add(word);
    }
    crossedWords = updated;
    notifyListeners();
  }

  /// Get list of participants who didn't ask or answer questions when time expired
  List<String> getInactivePlayers() {
    if (room == null) return [];

    final allParticipants = room!.participants.map((p) => p.id).toSet();
    final activeParticipants = <int>{};

    // Add all askers and targets
    for (final q in roundQuestions) {
      activeParticipants.add(q.askerId);
      activeParticipants.add(q.targetId);
    }

    final inactiveIds = allParticipants.difference(activeParticipants);
    return room!.participants
        .where((p) => inactiveIds.contains(p.id))
        .map((p) => p.nickname)
        .toList();
  }

  /// Proceed to voting phase after time expired
  void proceedToVoting() {
    timeExpired = false;
    roundPhase = GamePhases.voting;
    notifyListeners();
  }

  Future<void> _setToken(String? newToken, {bool persist = true}) async {
    token = newToken;
    authRepository.setAuthToken(newToken);
    if (persist && newToken != null) {
      await prefs.setString('auth_token', newToken);
    }
  }

  void _setRoomSession(RoomSession session) {
    if (socketRoomCode == session.room.code &&
        (socketStatus == 'connected' || socketStatus == 'connecting')) {
      _syncRoom(session.room);
      participant = session.participant;
      notifyListeners();
      return;
    }

    _syncRoom(session.room);
    participant = session.participant;
    socketService.connect(
      token: token ?? '',
      roomCode: session.room.code,
      onEvent: _handleSocketEvent,
      onStatus: (status) {
        if (status == 'connected') {
          socketRoomCode = session.room.code;
          refreshRoom();
        }
        if (status == 'disconnected') {
          socketRoomCode = null;
        }
        _setSocketStatus(status);
      },
      onError: (message) {
        errorMessage = 'Realtime connection lost';
        _setSocketStatus('error', error: message);
      },
    );
    _setSocketStatus(SocketStatus.connecting);
    _startPolling();
  }

  // ============================================================================
  // WebSocket Event Handling
  // ============================================================================

  /// Handle incoming socket events and update state accordingly.
  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
    if (type == null) return;

    if (type.startsWith('room.')) {
      // Handle room.expired event
      if (type == 'room.expired') {
        // Room expired due to inactivity - clear session state
        room = null;
        participant = null;
        _resetRoundState();
        socketService.disconnect();
        socketRoomCode = null;
        _stopPolling();
        showRound = true;
        roundPhase = 'role';
        _stopCountdown();
        notifyListeners();
        return; // Don't call refreshRoom() since we cleared the room
      }
      refreshRoom();
    }

    if (type.startsWith('round.')) {
      switch (type) {
        case 'round.started':
          final id = (payload?['round_id'] as num?)?.toInt();
          final duration = (payload?['duration'] as num?)?.toInt();
          final startedAt = payload?['started_at'] != null ? DateTime.tryParse(payload?['started_at']) : null;
          final countdownDuration = (payload?['countdown_seconds'] as num?)?.toInt() ?? room?.countdownSeconds ?? 5;
          final firstQuestion = (payload?['first_question'] as Map?)?.cast<String, dynamic>();
          // Always start with full countdown - ignore elapsed time to avoid countdown being 0
          final remainingCountdown = countdownDuration;
          final totalDuration = duration ?? room?.roundDurationSeconds ?? 300;
          _resetRoundState(roundId: id, status: 'in_progress');
          showRound = true;
          currentAskerId = (firstQuestion?['asker_id'] as num?)?.toInt();
          currentQuestionId = (firstQuestion?['question_id'] as num?)?.toInt();
          if (firstQuestion != null) {
            _pendingPhaseAfterCountdown = 'question';
          }
          roundPhase = 'countdown';
          final missionStartTime = (startedAt ?? DateTime.now()).add(Duration(seconds: countdownDuration));
          missionStart = missionStartTime;
          missionSeconds = _computeRemaining(totalDuration, missionStartTime);
          _startMissionTimer(totalDuration, missionStartTime);
          _startCountdown(remainingCountdown, onFinished: () {
            roundPhase = _pendingPhaseAfterCountdown ?? 'role';
            _pendingPhaseAfterCountdown = null;
            // Start turn timer when countdown finishes and we have a first asker
            if (currentAskerId != null && roundPhase == 'question') {
              _startTurnTimer(isAsking: true);
            }
            notifyListeners();
          });
          if (id != null) {
            loadRoundRole(id);
          }
          break;
        case 'round.question_turn':
          askedQuestion = false;
          turnTimedOut = false; // Reset timeout for new turn
          currentAskerId = (payload?['asker_id'] as num?)?.toInt();
          currentQuestionId = (payload?['question_id'] as num?)?.toInt();
          if (roundPhase == 'countdown') {
            _pendingPhaseAfterCountdown = 'question';
          } else {
            roundPhase = 'question';
          }
          // Start asking timer for this turn
          _startTurnTimer(isAsking: true);
          notifyListeners();
          break;
        case 'round.question':
          final text = payload?['text'] as String? ?? '';
          final qId = (payload?['question_id'] as num?)?.toInt() ?? 0;
          final newAskerId = (payload?['asker_id'] as num?)?.toInt();

          // Detect if this is a new turn (new asker)
          final isNewAsker = newAskerId != null && newAskerId != currentAskerId;

          currentQuestionId = qId;
          currentAskerId = newAskerId;
          roundPhase = countdownSeconds > 0 ? 'countdown' : 'question';

          // Check if this is a timed-out question
          final isTimedOutQuestion = text.trim() == '[Timed out]';

          // Only add to question list if there's actual text and it's not a timeout
          if (text.trim().isNotEmpty && !isTimedOutQuestion) {
            _upsertQuestion(RoundQuestionItem(
              id: qId,
              askerId: (payload?['asker_id'] as num?)?.toInt() ?? 0,
              targetId: (payload?['target_id'] as num?)?.toInt() ?? 0,
              text: text,
              askerName: payload?['asker_nickname'] as String?,
              targetName: payload?['target_nickname'] as String?,
            ));
          }

          // Handle timer based on whether it's a new turn or question submitted
          if (isNewAsker) {
            // New asker = new turn starting, they need to ask
            askedQuestion = false; // Reset for new asker
            turnTimedOut = false;
            _startTurnTimer(isAsking: true);
          } else if (isTimedOutQuestion) {
            // Timed out question - DON'T start answering timer, backend will send next turn
            _stopTurnTimer(); // Make sure no timer is running
          } else if (text.trim().isNotEmpty) {
            // Same asker but question has text = question was submitted, start answering
            _startTurnTimer(isAsking: false);
          }
          break;
        case 'round.answer':
          if (payload != null) {
            _markAnswer(
              (payload['question_id'] as num?)?.toInt() ?? 0,
              payload['text'] as String? ?? '',
            );
            // Answer was submitted, stop the timer
            _stopTurnTimer();
          }
          break;
        case 'round.all_questions_answered':
          allQuestionsAnswered = true;
          break;
        case 'round.ready_for_voting':
          if (payload != null) {
            readyForVotingCount = (payload['ready_count'] as num?)?.toInt() ?? 0;
          }
          break;
        case 'round.votes_updated':
          roundPhase = 'voting';
          _stopTurnTimer(); // Stop any active turn timer
          if (payload != null) {
            _ingestVotes(payload);
          }
          break;
        case 'round.phase':
          final phase = payload?['phase'] as String? ?? '';
          if (phase.isNotEmpty) {
            roundPhase = phase;
            if (phase == 'voting') {
              readyForVoting = false;
              readyForVotingCount = 0;
            }
          }
          break;
        case 'round.imposter_guess':
          guessSubmitted = true;
          break;
        case 'round.results':
          roundPhase = 'results';
          final roundId = (payload?['round_id'] as num?)?.toInt();
          fetchResults(roundId);
          break;
      }
      notifyListeners();
      refreshRoom();
    }
  }

  void _ingestVotes(Map<String, dynamic> payload) {
    final totals = (payload['totals'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(VoteTally.fromJson)
            .toList() ??
        [];
    voteTotals = {
      for (final t in totals) t.participantId: t.votes,
    };
  }

  void _syncRoom(Room latest) {
    room = latest;
    participant = latest.participants.firstWhere(
      (p) =>
          (user != null && p.userId == user!.id) ||
          (token != null && p.guestToken == token),
      orElse: () => participant ?? (latest.participants.isNotEmpty ? latest.participants.first : RoomParticipant.empty()),
    );
    _syncRoundFromRoom(latest);
  }

  void _syncRoundFromRoom(Room latest) {
    final newId = latest.activeRoundId;
    final newStatus = latest.activeRoundStatus;
    final idChanged = newId != activeRoundId;

    // If round ended (newId becomes null) while we're showing results, keep showing results
    if (idChanged && newId == null && roundPhase == 'results') {
      // Don't reset - keep showing results screen
      return;
    }

    if (idChanged) {
      _resetRoundState(roundId: newId, status: newStatus);
    } else {
      activeRoundStatus = newStatus;
      if (newStatus == 'in_progress' && roundPhase == 'role') {
        roundPhase = 'countdown';
      }
      // If round is scoring or ended, show results
      if (newStatus == 'scoring' || newStatus == 'ended') {
        roundPhase = 'results';
      }
    }

    if (newId != null && (idChanged || roundRole == null)) {
      loadRoundRole(newId);
    }

    if (latest.currentQuestion != null && latest.currentQuestion!.status == 'in_progress') {
      _hydrateCurrentQuestion(latest.currentQuestion);
    }

    _hydrateRoundTiming(latest);
  }

  void _resetRoundState({int? roundId, String? status}) {
    activeRoundId = roundId;
    activeRoundStatus = status;
    roundRole = null;
    roundResults = null;
    resultsRoundId = null;
    roundQuestions = [];
    voteTotals = {};
    notes = {};
    askedQuestion = false;
    voted = false;
    guessSubmitted = false;
    crossedWords = {};
    allQuestionsAnswered = false;
    readyForVoting = false;
    readyForVotingCount = 0;
    currentAskerId = null;
    currentQuestionId = null;
    _pendingPhaseAfterCountdown = null;
    roundPhase = status == 'in_progress' || status == 'countdown' ? 'countdown' : 'role';
    _stopCountdown();
    countdownSeconds = room?.countdownSeconds ?? 5;
    missionSeconds = null;
    missionStart = null;
    timeExpired = false;
    _timeExpiredHandled = false;
    _stopMissionTimer();
    _stopTurnTimer();
  }

  void _hydrateRoundTiming(Room roomData) {
    if (roomData.activeRoundStatus != 'in_progress') return;

    final countdownTotal = roomData.countdownSeconds;
    final totalDuration = roomData.roundDurationSeconds;
    final start = roomData.activeRoundStartedAt;
    final missionStartCandidate = start?.add(Duration(seconds: countdownTotal));
    var updated = false;

    if (missionStartCandidate != null && missionStart != missionStartCandidate) {
      missionStart = missionStartCandidate;
      missionSeconds = _computeRemaining(totalDuration, missionStartCandidate);
      _startMissionTimer(totalDuration, missionStartCandidate);
      updated = true;
    } else if (missionStart == null) {
      final fallbackStart = DateTime.now().add(Duration(seconds: countdownTotal));
      missionStart = fallbackStart;
      missionSeconds = _computeRemaining(totalDuration, fallbackStart);
      _startMissionTimer(totalDuration, fallbackStart);
      updated = true;
    } else if (_missionTimer == null && missionStart != null) {
      missionSeconds = _computeRemaining(totalDuration, missionStart!);
      _startMissionTimer(totalDuration, missionStart!);
      updated = true;
    }

    final elapsed = start != null ? DateTime.now().difference(start).inSeconds : 0;
    final remainingCountdown = (countdownTotal - elapsed).clamp(0, countdownTotal);

    // Only force countdown phase if we're in 'role' phase and countdown hasn't started yet
    // NEVER force back to countdown from question/voting/results phases
    if (roundPhase == 'role' && remainingCountdown > 0) {
      roundPhase = 'countdown';
      updated = true;
    }

    final shouldRestartCountdown =
        _countdownTimer == null || (start != null && countdownSeconds > remainingCountdown);
    if (shouldRestartCountdown && remainingCountdown > 0) {
      _startCountdown(remainingCountdown, onFinished: () {
        roundPhase = _pendingPhaseAfterCountdown ?? 'role';
        _pendingPhaseAfterCountdown = null;
        notifyListeners();
      });
      updated = true;
    } else if (remainingCountdown <= 0 && roundPhase == 'countdown') {
      countdownSeconds = 0;
      roundPhase = _pendingPhaseAfterCountdown ?? 'role';
      updated = true;
    }

    if (updated) {
      notifyListeners();
    }
  }

  void _hydrateCurrentQuestion(RoomQuestionSummary? summary) {
    if (summary == null) return;

    currentAskerId = summary.askerId;
    currentQuestionId = summary.id;

    // Only add to visible questions when text exists; but keep asker/phase for UI.
    if (summary.text.trim().isNotEmpty) {
      final exists = roundQuestions.any((q) => q.id == summary.id);
      if (!exists) {
        _upsertQuestion(
          RoundQuestionItem(
            id: summary.id,
            askerId: summary.askerId,
            targetId: summary.targetId,
            text: summary.text,
            askerName: room?.participants.firstWhere(
                      (p) => p.id == summary.askerId,
                      orElse: () => participant ?? RoomParticipant.empty(),
                    ).nickname ??
                '',
            targetName: room?.participants.firstWhere(
                      (p) => p.id == summary.targetId,
                      orElse: () => participant ?? RoomParticipant.empty(),
                    ).nickname ??
                '',
          ),
        );
      }
    }

    if (roundPhase != 'question' && countdownSeconds <= 0) {
      roundPhase = 'question';
    }
    notifyListeners();
  }

  void _upsertQuestion(RoundQuestionItem question) {
    final existingIndex = roundQuestions.indexWhere((q) => q.id == question.id);
    if (existingIndex >= 0) {
      roundQuestions[existingIndex] = question;
    } else {
      roundQuestions = [...roundQuestions, question];
    }
  }

  void _markAnswer(int questionId, String text) {
    roundQuestions = roundQuestions
        .map((q) => q.id == questionId ? q.copyWith(answer: text) : q)
        .toList();
    notifyListeners();
  }

  // ============================================================================
  // Helper Methods & Utilities
  // ============================================================================

  /// Start periodic polling to refresh room state.
  void _setSocketStatus(String status, {String? error}) {
    socketStatus = status;
    if (error != null) {
      socketError = error;
    } else if (status != SocketStatus.disconnected) {
      socketError = null;
    }
    notifyListeners();
  }

  /// Start periodic polling to refresh room state.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (room != null) {
        refreshRoom();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startCountdown(int seconds, {VoidCallback? onFinished}) {
    _stopCountdown();
    countdownSeconds = seconds < 0 ? 0 : seconds;
    roundPhase = 'countdown';
    if (countdownSeconds <= 0) {
      onFinished?.call();
      notifyListeners();
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownSeconds <= 1) {
        countdownSeconds = 0;
        onFinished?.call();
        timer.cancel();
      } else {
        countdownSeconds -= 1;
      }
      notifyListeners();
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _startMissionTimer(int duration, DateTime startedAt) {
    _stopMissionTimer();
    missionStart = startedAt;
    final total = duration;
    timeExpired = false;
    _timeExpiredHandled = false;
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newSeconds = _computeRemaining(total, startedAt);
      final oldSeconds = missionSeconds;
      missionSeconds = newSeconds;

      // Detect when timer hits 0 for the first time
      if (newSeconds == 0 && oldSeconds != null && oldSeconds > 0 && !_timeExpiredHandled) {
        timeExpired = true;
        _timeExpiredHandled = true;
        print('⏰ TIMER EXPIRED: Transitioning to time-up phase');
      }

      notifyListeners();
    });
  }

  void _stopMissionTimer() {
    _missionTimer?.cancel();
    _missionTimer = null;
  }

  /// Start a turn timer for asking or answering
  void _startTurnTimer({required bool isAsking}) {
    // CRITICAL: Stop any existing timer first
    _stopTurnTimer();

    isAskingPhase = isAsking;
    turnTimedOut = false; // Reset timeout flag
    final duration = isAsking
        ? TimingDefaults.askQuestionSeconds
        : TimingDefaults.answerQuestionSeconds;
    turnSeconds = duration;

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Check if timer was cancelled externally
      if (_turnTimer == null) {
        timer.cancel();
        return;
      }

      if (turnSeconds == null || turnSeconds! <= 1) {
        // About to hit 0, handle timeout
        timer.cancel();
        _handleTurnTimeout();
        return;
      }

      turnSeconds = turnSeconds! - 1;
      notifyListeners();
    });
  }

  void _stopTurnTimer() {
    if (_turnTimer != null) {
      _turnTimer!.cancel();
      _turnTimer = null;
    }
    turnSeconds = null;
    turnTimedOut = false;
  }

  /// Check if we should start a timer for the current player's turn
  void _ensureTurnTimerRunning() {
    // Prevent re-entry
    if (_isEnsuring) return;
    _isEnsuring = true;

    try {
      // Only check when in question phase
      if (roundPhase != 'question') return;

      // If timer is already running or timed out, don't interfere
      if (turnSeconds != null || turnTimedOut) return;

      // If no current asker, nothing to do
      if (currentAskerId == null || participant == null) return;

      // Check if it's this participant's turn to ask
      if (currentAskerId == participant!.id && !askedQuestion) {
        _startTurnTimer(isAsking: true);
        return;
      }

      // Check if there's a pending question for this participant to answer
      final pendingQ = pendingQuestions.firstWhere(
        (q) => q.id == currentQuestionId && q.targetId == participant!.id,
        orElse: () => RoundQuestionItem(id: 0, askerId: 0, targetId: 0, text: ''),
      );

      if (pendingQ.id > 0 && currentAskerId != participant!.id) {
        _startTurnTimer(isAsking: false);
      }
    } finally {
      _isEnsuring = false;
    }
  }

  /// Handle when a turn timer expires
  void _handleTurnTimeout() {

    // Stop the timer immediately
    if (_turnTimer != null) {
      _turnTimer!.cancel();
      _turnTimer = null;
    }

    turnTimedOut = true;
    turnSeconds = 0; // Set to 0 to show "0s"

    // Mark question as "asked" to prevent submission
    if (isAskingPhase) {
      askedQuestion = true;
    }

    notifyListeners();

    // Auto-submit empty response to progress the game
    _autoSkipTurn();
  }

  /// Automatically skip turn by submitting timeout marker to backend
  Future<void> _autoSkipTurn() async {
    if (activeRoundId == null || participant == null) return;

    try {
      if (isAskingPhase && currentAskerId == participant!.id) {
        // This player was supposed to ask but timed out
        // Submit to random valid target so backend knows to move on
        final validTargets = room?.participants.where((p) => p.id != participant!.id).toList() ?? [];
        if (validTargets.isEmpty) {
          return;
        }

        // Pick a RANDOM target to avoid patterns
        final randomIndex = DateTime.now().millisecondsSinceEpoch % validTargets.length;
        final randomTarget = validTargets[randomIndex];

        await roundRepository.askQuestion(
          roundId: activeRoundId!,
          targetId: randomTarget.id,
          text: '[Timed out]',
          askerId: participant!.id,
        );
      } else if (!isAskingPhase && currentQuestionId != null) {
        // Someone needs to answer but timed out
        // Submit empty answer so backend knows to move on
        final pendingQ = pendingQuestions.firstWhere(
          (q) => q.id == currentQuestionId,
          orElse: () => RoundQuestionItem(id: 0, askerId: 0, targetId: 0, text: ''),
        );

        if (pendingQ.id > 0 && pendingQ.targetId == participant!.id) {
          await roundRepository.answerQuestion(
            roundId: activeRoundId!,
            questionId: currentQuestionId!,
            text: '[Timed out]',
          );
        }
      }
    } catch (e) {
      // Don't show error to user, backend will progress anyway
    }
  }

  int _computeRemaining(int totalSeconds, DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = totalSeconds - elapsed;
    if (remaining < 0) return 0;
    if (remaining > totalSeconds) return totalSeconds;
    return remaining;
  }

  Future<void> _runGuarded(
    Future<void> Function() action, {
    required String fallbackMessage,
    bool setLoading = true,
  }) async {
    errorMessage = null;
    if (setLoading) {
      loading = true;
      notifyListeners();
    }
    try {
      await action();
    } catch (e) {
      errorMessage = _friendlyMessage(e, fallbackMessage);
    } finally {
      if (setLoading) {
        loading = false;
      }
      notifyListeners();
    }
  }

  String _friendlyMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
      if (data is Map && data.values.isNotEmpty) {
        final first = data.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
    }
    return fallback;
  }
}
