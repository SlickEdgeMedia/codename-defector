import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/models/room.dart';

class RoomRepository {
  RoomRepository(this._api);

  final ApiClient _api;

  Future<RoomSession> createRoom({
    required String nickname,
    int? rounds,
    int? discussionSeconds,
    int? votingSeconds,
    int? maxPlayers,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/rooms',
      data: {
        'nickname': nickname,
        if (rounds != null) 'rounds': rounds,
        if (discussionSeconds != null) 'discussion_seconds': discussionSeconds,
        if (votingSeconds != null) 'voting_seconds': votingSeconds,
        if (maxPlayers != null) 'max_players': maxPlayers,
      },
    );

    return RoomSession.fromJson(response.data ?? {});
  }

  Future<RoomSession> joinRoom({
    required String code,
    required String nickname,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/rooms/$code/join',
      data: {'nickname': nickname},
    );

    return RoomSession.fromJson(response.data ?? {});
  }

  Future<RoomSession> setReady({
    required String code,
    required bool ready,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/rooms/$code/ready',
      data: {'ready': ready},
    );

    return RoomSession.fromJson(response.data ?? {});
  }

  Future<void> leaveRoom(String code) async {
    await _api.post('/rooms/$code/leave');
  }

  Future<Room> fetchRoom(String code) async {
    final response = await _api.get<Map<String, dynamic>>('/rooms/$code');
    final data = response.data ?? {};
    return Room.fromJson(data['data'] ?? data);
  }
}
