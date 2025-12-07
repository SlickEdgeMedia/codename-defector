import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/models/auth_models.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/models/user.dart';
import 'package:imposter_app/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.roomRepository,
    required this.socketService,
    required this.prefs,
  });

  final AuthRepository authRepository;
  final RoomRepository roomRepository;
  final SocketService socketService;
  final SharedPreferences prefs;

  bool loading = false;
  String? token;
  UserProfile? user;
  Room? room;
  RoomParticipant? participant;
  String? errorMessage;
  String socketStatus = 'disconnected';
  String? socketError;

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
    }, fallbackMessage: 'Login failed');
  }

  Future<void> logout() async {
    token = null;
    user = null;
    room = null;
    participant = null;
    socketStatus = 'disconnected';
    socketError = null;
    socketService.disconnect();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> createRoom({required String nickname}) async {
    if (token == null) return;
    await _runGuarded(() async {
      final session = await roomRepository.createRoom(nickname: nickname);
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
      socketService.disconnect();
    }, fallbackMessage: 'Failed to leave room');
  }

  Future<void> refreshRoom() async {
    if (room == null) return;
    try {
      final latest = await roomRepository.fetchRoom(room!.code);
      room = latest;
      participant = latest.participants.firstWhere(
        (p) => p.userId == user?.id,
        orElse: () => participant ?? latest.participants.first,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _setToken(String? newToken, {bool persist = true}) async {
    token = newToken;
    authRepository.setAuthToken(newToken);
    if (persist && newToken != null) {
      await prefs.setString('auth_token', newToken);
    }
  }

  void _setRoomSession(RoomSession session) {
    room = session.room;
    participant = session.participant;
    socketService.connect(
      token: token ?? '',
      roomCode: session.room.code,
      onEvent: (_) => refreshRoom(),
      onStatus: (status) {
        _setSocketStatus(status);
      },
      onError: (message) {
        errorMessage = 'Realtime connection lost';
        _setSocketStatus('error', error: message);
      },
    );
    _setSocketStatus('connecting');
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
