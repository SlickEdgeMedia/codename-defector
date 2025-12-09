class WordOption {
  WordOption({required this.id, required this.text});

  final int id;
  final String text;

  factory WordOption.fromJson(Map<String, dynamic> json) {
    return WordOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
    );
  }
}

class RoundRoleInfo {
  RoundRoleInfo({
    required this.roundId,
    required this.roundNumber,
    required this.role,
    required this.category,
    this.word,
    this.wordOptions = const [],
  });

  final int roundId;
  final int roundNumber;
  final String role; // imposter | civilian
  final String category;
  final String? word;
  final List<WordOption> wordOptions;

  bool get isImposter => role == 'imposter';
  List<String> get wordList => wordOptions.map((w) => w.text).toList();

  factory RoundRoleInfo.fromJson(Map<String, dynamic> json) {
    final list = (json['word_list'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(WordOption.fromJson)
            .toList() ??
        [];
    return RoundRoleInfo(
      roundId: (json['round_id'] as num?)?.toInt() ?? 0,
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      role: json['role'] as String? ?? 'civilian',
      category: json['category'] as String? ?? '',
      word: json['word'] as String?,
      wordOptions: list,
    );
  }
}

class RoundQuestionItem {
  RoundQuestionItem({
    required this.id,
    required this.askerId,
    required this.targetId,
    required this.text,
    this.askerName,
    this.targetName,
    this.answer,
  });

  final int id;
  final int askerId;
  final int targetId;
  final String text;
  final String? askerName;
  final String? targetName;
  final String? answer;

  RoundQuestionItem copyWith({String? answer}) {
    return RoundQuestionItem(
      id: id,
      askerId: askerId,
      targetId: targetId,
      text: text,
      askerName: askerName,
      targetName: targetName,
      answer: answer ?? this.answer,
    );
  }
}

class VoteTally {
  VoteTally({required this.participantId, required this.votes});

  final int participantId;
  final int votes;

  factory VoteTally.fromJson(Map<String, dynamic> json) {
    return VoteTally(
      participantId: (json['participant_id'] as num?)?.toInt() ?? 0,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoundScoreEntry {
  RoundScoreEntry({
    required this.participantId,
    required this.nickname,
    required this.points,
    required this.reason,
  });

  final int participantId;
  final String nickname;
  final int points;
  final String reason;

  factory RoundScoreEntry.fromJson(Map<String, dynamic> json) {
    return RoundScoreEntry(
      participantId: (json['participant_id'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }
}

class RoundResults {
  RoundResults({
    required this.roundId,
    required this.status,
    required this.imposterParticipantId,
    required this.scores,
  });

  final int roundId;
  final String status;
  final int? imposterParticipantId;
  final List<RoundScoreEntry> scores;

  factory RoundResults.fromJson(Map<String, dynamic> json) {
    final scores = (json['scores'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(RoundScoreEntry.fromJson)
            .toList() ??
        [];
    return RoundResults(
      roundId: (json['round_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      imposterParticipantId: (json['imposter_participant_id'] as num?)?.toInt(),
      scores: scores,
    );
  }
}
