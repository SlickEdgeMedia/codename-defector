/// Game phase constants used throughout the app.
///
/// These represent the different phases of a round in The Imposter game.
class GamePhases {
  /// Role reveal phase - shows player's assigned role
  static const String role = 'role';

  /// Countdown phase - timer before mission starts
  static const String countdown = 'countdown';

  /// Question phase - players interrogate each other
  static const String question = 'question';

  /// Voting phase - players vote for suspected imposter
  static const String voting = 'voting';

  /// Results phase - shows scoring and outcome
  static const String results = 'results';

  /// All valid phase names
  static const List<String> all = [
    role,
    countdown,
    question,
    voting,
    results,
  ];
}

/// Socket.IO event type constants.
///
/// These are the real-time events emitted by the server.
class SocketEvents {
  // Room events
  static const String roomCreated = 'room.created';
  static const String roomJoined = 'room.joined';
  static const String roomReadyUpdated = 'room.ready_updated';
  static const String roomLeft = 'room.left';
  static const String roomClosed = 'room.closed';

  // Round lifecycle events
  static const String roundStarted = 'round.started';
  static const String roundPhase = 'round.phase';
  static const String roundResults = 'round.results';

  // Question/answer events
  static const String roundQuestionTurn = 'round.question_turn';
  static const String roundQuestion = 'round.question';
  static const String roundAnswer = 'round.answer';

  // Voting events
  static const String roundVotesUpdated = 'round.votes_updated';

  // Imposter guess event
  static const String roundImposterGuess = 'round.imposter_guess';
}

/// Socket connection status constants.
class SocketStatus {
  static const String connected = 'connected';
  static const String connecting = 'connecting';
  static const String disconnected = 'disconnected';
  static const String error = 'error';
}

/// Round status constants from backend.
class RoundStatus {
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String voting = 'voting';
  static const String scoring = 'scoring';
  static const String ended = 'ended';
}

/// Room status constants from backend.
class RoomStatus {
  static const String lobby = 'lobby';
  static const String inRound = 'in_round';
  static const String ended = 'ended';
}

/// Default timing constants (in seconds).
class TimingDefaults {
  /// Default countdown duration before round starts
  static const int countdownSeconds = 5;

  /// Default round duration
  static const int roundDurationSeconds = 300; // 5 minutes

  /// Default polling interval for room refresh
  static const int pollIntervalSeconds = 4;

  /// Minimum players required to start a round
  static const int minPlayers = 3;

  /// Maximum players per room
  static const int maxPlayers = 12;

  /// Time allowed for each player to ask a question
  static const int askQuestionSeconds = 30;

  /// Time allowed for each player to answer a question
  static const int answerQuestionSeconds = 20;
}
