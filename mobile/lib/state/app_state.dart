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
    errorMessage = null;
    loading = true;
    notifyListeners();
    try {
      final result = await authRepository.register(
        name: name,
        email: email,
        password: password,
      );
      await _setToken(result.token);
      user = result.user;
    } catch (e) {
      errorMessage = 'Registration failed';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    errorMessage = null;
    loading = true;
    notifyListeners();
    try {
      final result = await authRepository.login(
        email: email,
        password: password,
      );
      await _setToken(result.token);
      user = result.user;
    } catch (e) {
      errorMessage = 'Login failed';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    user = null;
    room = null;
    participant = null;
    socketService.disconnect();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> createRoom({required String nickname}) async {
    if (token == null) return;
    errorMessage = null;
    loading = true;
    notifyListeners();
    try {
      final session = await roomRepository.createRoom(nickname: nickname);
      _setRoomSession(session);
    } catch (e) {
      errorMessage = 'Failed to create room';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> joinRoom({
    required String code,
    required String nickname,
  }) async {
    if (token == null) return;
    errorMessage = null;
    loading = true;
    notifyListeners();
    try {
      final session = await roomRepository.joinRoom(
        code: code,
        nickname: nickname,
      );
      _setRoomSession(session);
    } catch (e) {
      errorMessage = 'Failed to join room';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setReady(bool ready) async {
    if (room == null || token == null) return;
    errorMessage = null;
    try {
      final session = await roomRepository.setReady(
        code: room!.code,
        ready: ready,
      );
      _setRoomSession(session);
    } catch (e) {
      errorMessage = 'Failed to update ready state';
      notifyListeners();
    }
  }

  Future<void> leaveRoom() async {
    if (room == null || token == null) return;
    errorMessage = null;
    loading = true;
    notifyListeners();
    try {
      await roomRepository.leaveRoom(room!.code);
      room = null;
      participant = null;
      socketService.disconnect();
    } catch (e) {
      errorMessage = 'Failed to leave room';
    } finally {
      loading = false;
      notifyListeners();
    }
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
    );
  }
}
