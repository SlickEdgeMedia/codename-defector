import 'package:imposter_app/models/user.dart';

class RoomParticipant {
  RoomParticipant({
    required this.id,
    required this.roomId,
    this.userId,
    this.guestToken,
    required this.nickname,
    required this.isHost,
    required this.readyAt,
    this.user,
  });

  final int id;
  final int roomId;
  final int? userId;
  final String? guestToken;
  final String nickname;
  final bool isHost;
  final DateTime? readyAt;
  final UserProfile? user;

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomId: (json['room_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt(),
      guestToken: json['guest_token'] as String?,
      nickname: json['nickname'] as String? ?? '',
      isHost: json['is_host'] as bool? ?? false,
      readyAt: json['ready_at'] != null ? DateTime.tryParse(json['ready_at']) : null,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
    );
  }

  factory RoomParticipant.empty() {
    return RoomParticipant(
      id: 0,
      roomId: 0,
      userId: null,
      guestToken: null,
      nickname: '',
      isHost: false,
      readyAt: null,
    );
  }

  String displayName() => user?.name ?? nickname;
}

class Room {
  Room({
    required this.id,
    required this.code,
    required this.status,
    this.hostUserId,
    this.hostGuestToken,
    required this.maxPlayers,
    required this.rounds,
    required this.discussionSeconds,
    required this.votingSeconds,
    required this.category,
    required this.roundDurationSeconds,
    this.activeRoundId,
    this.activeRoundStatus,
    this.activeRoundNumber,
    this.activeRoundStartedAt,
    this.currentQuestion,
    required this.participants,
    this.countdownSeconds = 5,
  });

  final int id;
  final String code;
  final String status;
  final int? hostUserId;
  final String? hostGuestToken;
  final int maxPlayers;
  final int rounds;
  final int discussionSeconds;
  final int votingSeconds;
  final String category;
  final int roundDurationSeconds;
  final int? activeRoundId;
  final String? activeRoundStatus;
  final int? activeRoundNumber;
  final DateTime? activeRoundStartedAt;
  final RoomQuestionSummary? currentQuestion;
  final int countdownSeconds;
  final List<RoomParticipant> participants;

  factory Room.fromJson(Map<String, dynamic> json) {
    final participantsJson =
        (json['participants'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Room(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      hostUserId: (json['host_user_id'] as num?)?.toInt(),
      hostGuestToken: json['host_guest_token'] as String?,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 0,
      rounds: (json['rounds'] as num?)?.toInt() ?? 0,
      discussionSeconds: (json['discussion_seconds'] as num?)?.toInt() ?? 0,
      votingSeconds: (json['voting_seconds'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'countries',
      roundDurationSeconds: (json['round_duration_seconds'] as num?)?.toInt() ?? 300,
      activeRoundId: (json['active_round_id'] as num?)?.toInt(),
      activeRoundStatus: json['active_round_status'] as String?,
      activeRoundNumber: (json['active_round_number'] as num?)?.toInt(),
      activeRoundStartedAt: json['active_round_started_at'] != null
          ? DateTime.tryParse(json['active_round_started_at'])
          : null,
      currentQuestion: json['current_question'] != null
          ? RoomQuestionSummary.fromJson(
              (json['current_question'] as Map<dynamic, dynamic>).cast<String, dynamic>(),
            )
          : null,
      countdownSeconds: (json['countdown_seconds'] as num?)?.toInt() ?? 5,
      participants: participantsJson.map(RoomParticipant.fromJson).toList(),
    );
  }
}

class RoomQuestionSummary {
  RoomQuestionSummary({
    required this.id,
    required this.askerId,
    required this.targetId,
    required this.text,
    required this.order,
    required this.status,
  });

  final int id;
  final int askerId;
  final int targetId;
  final String text;
  final int order;
  final String status;

  factory RoomQuestionSummary.fromJson(Map<String, dynamic> json) {
    return RoomQuestionSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      askerId: (json['asker_id'] as num?)?.toInt() ?? 0,
      targetId: (json['target_id'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
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
      participant: RoomParticipant.fromJson(json['participant'] as Map<String, dynamic>),
    );
  }
}
