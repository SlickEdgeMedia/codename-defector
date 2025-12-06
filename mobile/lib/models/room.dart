import 'package:imposter_app/models/user.dart';

class RoomParticipant {
  RoomParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.nickname,
    required this.isHost,
    required this.readyAt,
    this.user,
  });

  final int id;
  final int roomId;
  final int userId;
  final String nickname;
  final bool isHost;
  final DateTime? readyAt;
  final UserProfile? user;

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomId: (json['room_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      isHost: json['is_host'] as bool? ?? false,
      readyAt: json['ready_at'] != null
          ? DateTime.tryParse(json['ready_at'])
          : null,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
    );
  }
}

class Room {
  Room({
    required this.id,
    required this.code,
    required this.status,
    required this.hostUserId,
    required this.maxPlayers,
    required this.rounds,
    required this.discussionSeconds,
    required this.votingSeconds,
    required this.participants,
  });

  final int id;
  final String code;
  final String status;
  final int hostUserId;
  final int maxPlayers;
  final int rounds;
  final int discussionSeconds;
  final int votingSeconds;
  final List<RoomParticipant> participants;

  factory Room.fromJson(Map<String, dynamic> json) {
    final participantsJson =
        (json['participants'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return Room(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      hostUserId: (json['host_user_id'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 0,
      rounds: (json['rounds'] as num?)?.toInt() ?? 0,
      discussionSeconds: (json['discussion_seconds'] as num?)?.toInt() ?? 0,
      votingSeconds: (json['voting_seconds'] as num?)?.toInt() ?? 0,
      participants: participantsJson.map(RoomParticipant.fromJson).toList(),
    );
  }
}

class RoomSession {
  RoomSession({required this.room, required this.participant});

  final Room room;
  final RoomParticipant participant;

  factory RoomSession.fromJson(Map<String, dynamic> json) {
    return RoomSession(
      room: Room.fromJson(json['room'] as Map<String, dynamic>),
      participant: RoomParticipant.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
    );
  }
}
