import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/data/round_repository.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/models/round_models.dart';
import 'package:imposter_app/models/user.dart';
import 'package:imposter_app/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.roomRepository,
    required this.roundRepository,
    required this.socketService,
    required this.prefs,
  });

  final AuthRepository authRepository;
  final RoomRepository roomRepository;
  final RoundRepository roundRepository;
  final SocketService socketService;
  final SharedPreferences prefs;

  bool loading = false;
  bool roundLoading = false;
  String? token;
  UserProfile? user;
  String? guestNickname;
  Room? room;
  RoomParticipant? participant;
  String? errorMessage;
  String? bannerMessage;
  String socketStatus = 'disconnected';
  String? socketError;
  String? socketRoomCode;
  int? activeRoundId;
  String? activeRoundStatus;
  RoundRoleInfo? roundRole;
  RoundResults? roundResults;
  List<RoundQuestionItem> roundQuestions = [];
  Map<int, int> voteTotals = {};
  Map<int, String> notes = {};
  bool askedQuestion = false;
  bool voted = false;
  bool guessSubmitted = false;
  Set<String> crossedWords = {};
  int? currentQuestionId;
  int? currentAskerId;
  List<String> eventLog = [];
  Timer? _pollTimer;
  bool showRound = true;
  String roundPhase = 'role'; // countdown | role | question | voting | results
  int countdownSeconds = 5;
  String? _pendingPhaseAfterCountdown;
  Timer? _countdownTimer;
  int? missionSeconds;
  DateTime? missionStart;
  Timer? _missionTimer;

  void _setSocketStatus(String status, {String? error}) {
    socketStatus = status;
    if (error != null) {
      socketError = error;
    } else if (status != 'disconnected') {
      socketError = null;
    }
    notifyListeners();
  }

  Future<void> bootstrap() async {
    final savedToken = prefs.getString('auth_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      await _setToken(savedToken, persist: false);
      await refreshSession();
    }
  }

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

  Future<void> createRoom({
    required String nickname,
    required String category,
    required int roundDurationSeconds,
  }) async {
    if (token == null) return;
    await _runGuarded(() async {
      final session = await roomRepository.createRoom(
        nickname: nickname,
        category: category,
        roundDurationSeconds: roundDurationSeconds,
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
    roundPhase = 'role';
    notifyListeners();
    await refreshRoom();
  }

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
      missionStart = startedAt;
      missionSeconds = _computeRemaining(duration, startedAt);
      _startMissionTimer(duration, startedAt);
      _startCountdown(countdownTotal, onFinished: () {
        roundPhase = _pendingPhaseAfterCountdown ?? 'role';
        _pendingPhaseAfterCountdown = null;
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
    final id = roundId ?? activeRoundId;
    if (id == null) return;
    try {
      roundResults = await roundRepository.fetchResults(id);
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  List<RoundQuestionItem> get pendingQuestions {
    if (participant == null) return [];
    return roundQuestions
        .where((q) => q.targetId == participant!.id && q.answer == null)
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
    _setSocketStatus('connecting');
    _startPolling();
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
    if (type == null) return;

    if (type.startsWith('room.')) {
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
          final elapsed = startedAt != null ? DateTime.now().difference(startedAt).inSeconds : 0;
          final remainingCountdown = (countdownDuration - elapsed).clamp(0, countdownDuration);
          final totalDuration = duration ?? room?.roundDurationSeconds ?? 300;
          _resetRoundState(roundId: id, status: 'in_progress');
          showRound = true;
          currentAskerId = (firstQuestion?['asker_id'] as num?)?.toInt();
          currentQuestionId = (firstQuestion?['question_id'] as num?)?.toInt();
          if (firstQuestion != null) {
            _pendingPhaseAfterCountdown = 'question';
          }
          roundPhase = 'countdown';
          missionStart = startedAt ?? DateTime.now();
          missionSeconds = _computeRemaining(totalDuration, missionStart!);
          _startMissionTimer(totalDuration, missionStart!);
          _startCountdown(remainingCountdown, onFinished: () {
            roundPhase = _pendingPhaseAfterCountdown ?? 'role';
            _pendingPhaseAfterCountdown = null;
            notifyListeners();
          });
          if (id != null) {
            loadRoundRole(id);
          }
          break;
        case 'round.question_turn':
          askedQuestion = false;
          currentAskerId = (payload?['asker_id'] as num?)?.toInt();
          currentQuestionId = (payload?['question_id'] as num?)?.toInt();
          if (roundPhase == 'countdown') {
            _pendingPhaseAfterCountdown = 'question';
          } else {
            roundPhase = 'question';
          }
          notifyListeners();
          break;
        case 'round.question':
          final qId = (payload?['question_id'] as num?)?.toInt() ?? 0;
          currentQuestionId = qId;
          currentAskerId = (payload?['asker_id'] as num?)?.toInt();
          roundPhase = countdownSeconds > 0 ? 'countdown' : 'question';
          if (payload != null) {
            _upsertQuestion(RoundQuestionItem(
              id: qId,
              askerId: (payload['asker_id'] as num?)?.toInt() ?? 0,
              targetId: (payload['target_id'] as num?)?.toInt() ?? 0,
              text: payload['text'] as String? ?? '',
              askerName: payload['asker_nickname'] as String?,
              targetName: payload['target_nickname'] as String?,
            ));
          }
          break;
        case 'round.answer':
          if (payload != null) {
            _markAnswer(
              (payload['question_id'] as num?)?.toInt() ?? 0,
              payload['text'] as String? ?? '',
            );
          }
          break;
        case 'round.votes_updated':
          roundPhase = 'voting';
          if (payload != null) {
            _ingestVotes(payload);
          }
          break;
        case 'round.phase':
          final phase = payload?['phase'] as String? ?? '';
          if (phase.isNotEmpty) {
            roundPhase = phase;
          }
          break;
        case 'round.imposter_guess':
          guessSubmitted = true;
          break;
        case 'round.results':
          roundPhase = 'results';
          fetchResults((payload?['round_id'] as num?)?.toInt());
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

    if (idChanged) {
      _resetRoundState(roundId: newId, status: newStatus);
    } else {
      activeRoundStatus = newStatus;
      if (newStatus == 'in_progress' && roundPhase == 'role') {
        roundPhase = 'countdown';
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
    roundQuestions = [];
    voteTotals = {};
    notes = {};
    askedQuestion = false;
    voted = false;
    guessSubmitted = false;
    crossedWords = {};
    currentAskerId = null;
    currentQuestionId = null;
    _pendingPhaseAfterCountdown = null;
    roundPhase = status == 'in_progress' || status == 'countdown' ? 'countdown' : 'role';
    _stopCountdown();
    countdownSeconds = room?.countdownSeconds ?? 5;
    missionSeconds = null;
    missionStart = null;
    _stopMissionTimer();
  }

  void _hydrateRoundTiming(Room roomData) {
    if (roomData.activeRoundStatus != 'in_progress') return;

    final countdownTotal = roomData.countdownSeconds;
    final totalDuration = roomData.roundDurationSeconds;
    final start = roomData.activeRoundStartedAt;
    var updated = false;

    if (start != null && missionStart != start) {
      missionStart = start;
      missionSeconds = _computeRemaining(totalDuration, start);
      _startMissionTimer(totalDuration, start);
      updated = true;
    } else if (missionStart == null) {
      missionStart = DateTime.now();
      missionSeconds = _computeRemaining(totalDuration, missionStart!);
      _startMissionTimer(totalDuration, missionStart!);
      updated = true;
    } else if (_missionTimer == null && missionStart != null) {
      missionSeconds = _computeRemaining(totalDuration, missionStart!);
      _startMissionTimer(totalDuration, missionStart!);
      updated = true;
    }

    final elapsed = start != null ? DateTime.now().difference(start).inSeconds : 0;
    final remainingCountdown = (countdownTotal - elapsed).clamp(0, countdownTotal);

    if (roundPhase != 'countdown' && remainingCountdown > 0) {
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

    // If we don't already have this question, add it so targets see it in the queue.
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
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      missionSeconds = _computeRemaining(total, startedAt);
      notifyListeners();
    });
  }

  void _stopMissionTimer() {
    _missionTimer?.cancel();
    _missionTimer = null;
  }

  int _computeRemaining(int totalSeconds, DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = totalSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
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
