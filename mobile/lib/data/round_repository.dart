import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/models/round_models.dart';

class RoundRepository {
  RoundRepository(this._api);

  final ApiClient _api;

  Future<RoundStartInfo> startRound(String roomCode) async {
    final response =
        await _api.post<Map<String, dynamic>>('/rooms/$roomCode/rounds/start');
    final data = response.data ?? {};
    final fq = (data['first_question'] as Map?)?.cast<String, dynamic>();
    return RoundStartInfo(
      roundId: (data['round_id'] as num?)?.toInt() ?? 0,
      startedAt: data['started_at'] != null ? DateTime.tryParse(data['started_at']) : null,
      countdownSeconds: (data['countdown_seconds'] as num?)?.toInt(),
      roundDurationSeconds: (data['round_duration_seconds'] as num?)?.toInt(),
      firstQuestionId: (fq?['question_id'] as num?)?.toInt(),
      firstAskerId: (fq?['asker_id'] as num?)?.toInt(),
      firstTargetId: (fq?['target_id'] as num?)?.toInt(),
      firstOrder: (fq?['order'] as num?)?.toInt(),
    );
  }

  Future<RoundRoleInfo> fetchRole(int roundId) async {
    final response =
        await _api.get<Map<String, dynamic>>('/rounds/$roundId/role');
    return RoundRoleInfo.fromJson(response.data ?? {});
  }

  Future<RoundQuestionItem> askQuestion({
    required int roundId,
    required int targetId,
    required String text,
    required int askerId,
    String? askerName,
    String? targetName,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/questions',
      data: {'target_participant_id': targetId, 'text': text},
    );
    final data = response.data ?? {};
    final id = (data['id'] as num?)?.toInt() ?? 0;
    return RoundQuestionItem(
      id: id,
      askerId: (data['asker_id'] as num?)?.toInt() ?? askerId,
      targetId: (data['target_id'] as num?)?.toInt() ?? targetId,
      text: data['text'] as String? ?? text,
      askerName: data['asker_nickname'] as String? ?? askerName,
      targetName: data['target_nickname'] as String? ?? targetName,
    );
  }

  Future<void> answerQuestion({
    required int roundId,
    required int questionId,
    required String text,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/answers',
      data: {'question_id': questionId, 'text': text},
    );
  }

  Future<void> vote({
    required int roundId,
    required int targetId,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/votes',
      data: {'target_participant_id': targetId},
    );
  }

  Future<void> imposterGuess({
    required int roundId,
    required int wordId,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/guess',
      data: {'word_id': wordId},
    );
  }

  Future<void> guessWord({
    required int roundId,
    required String guess,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/guess',
      data: {'guess': guess},
    );
  }

  Future<void> markReadyForVoting({required int roundId}) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/ready-for-voting',
    );
  }

  Future<void> skipGuess({required int roundId}) async {
    await _api.post<Map<String, dynamic>>(
      '/rounds/$roundId/skip-guess',
    );
  }

  Future<RoundResults> fetchResults(int roundId) async {
    final response =
        await _api.get<Map<String, dynamic>>('/rounds/$roundId/results');
    print('🔵 fetchResults API response: ${response.data}');
    return RoundResults.fromJson(response.data ?? {});
  }
}

class RoundStartInfo {
  RoundStartInfo({
    required this.roundId,
    this.startedAt,
    this.countdownSeconds,
    this.roundDurationSeconds,
    this.firstQuestionId,
    this.firstAskerId,
    this.firstTargetId,
    this.firstOrder,
  });

  final int roundId;
  final DateTime? startedAt;
  final int? countdownSeconds;
  final int? roundDurationSeconds;
  final int? firstQuestionId;
  final int? firstAskerId;
  final int? firstTargetId;
  final int? firstOrder;
}
