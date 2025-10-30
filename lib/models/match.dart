class Match {
  final String matchId;
  final String lobbyId;
  final List<List<String>> board; // 4x4 or 5x5 letters
  final int timer; // seconds remaining
  final List<String> myWords;
  final List<String> opponentWords;
  final bool completed;
  final int myScore;
  final int? myWordScore;
  final int? myTimeBonus;
  final int opponentScore;
  final String? opponentId;
  final String opponentUsername;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int entryFee;
  final int prizePool;
  final int gameDuration;
  // Per-player absolute deadline
  final DateTime? playerDeadlineAt;

  const Match({
    required this.matchId,
    required this.lobbyId,
    required this.board,
    required this.timer,
    required this.myWords,
    required this.opponentWords,
    required this.completed,
    required this.myScore,
    this.myWordScore,
    this.myTimeBonus,
    required this.opponentScore,
    this.opponentId,
    required this.opponentUsername,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    required this.entryFee,
    required this.prizePool,
    required this.gameDuration,
    this.playerDeadlineAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchId: json['matchId'] as String,
      lobbyId: json['lobbyId'] as String,
      board: (json['board'] as List)
          .map((row) => (row as List).cast<String>())
          .toList(),
      timer: json['timer'] as int,
      myWords: (json['myWords'] as List).cast<String>(),
      opponentWords: (json['opponentWords'] as List).cast<String>(),
      completed: json['completed'] as bool,
      myScore: json['myScore'] as int,
      myWordScore: json['myWordScore'] as int?,
      myTimeBonus: json['myTimeBonus'] as int?,
      opponentScore: json['opponentScore'] as int,
      opponentId: json['opponentId'] as String?,
      opponentUsername: json['opponentUsername'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      entryFee: json['entryFee'] as int,
      prizePool: json['prizePool'] as int,
      gameDuration: json['gameDuration'] as int,
      playerDeadlineAt: json['playerDeadlineAt'] != null
          ? DateTime.parse(json['playerDeadlineAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'lobbyId': lobbyId,
      'board': board,
      'timer': timer,
      'myWords': myWords,
      'opponentWords': opponentWords,
      'completed': completed,
      'myScore': myScore,
      'myWordScore': myWordScore,
      'myTimeBonus': myTimeBonus,
      'opponentScore': opponentScore,
      'opponentId': opponentId,
      'opponentUsername': opponentUsername,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'entryFee': entryFee,
      'prizePool': prizePool,
      'gameDuration': gameDuration,
      'playerDeadlineAt': playerDeadlineAt?.toIso8601String(),
    };
  }

  Match copyWith({
    String? matchId,
    String? lobbyId,
    List<List<String>>? board,
    int? timer,
    List<String>? myWords,
    List<String>? opponentWords,
    bool? completed,
    int? myScore,
    int? myWordScore,
    int? myTimeBonus,
    int? opponentScore,
    String? opponentId,
    String? opponentUsername,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? entryFee,
    int? prizePool,
    int? gameDuration,
    DateTime? playerDeadlineAt,
  }) {
    return Match(
      matchId: matchId ?? this.matchId,
      lobbyId: lobbyId ?? this.lobbyId,
      board: board ?? this.board,
      timer: timer ?? this.timer,
      myWords: myWords ?? this.myWords,
      opponentWords: opponentWords ?? this.opponentWords,
      completed: completed ?? this.completed,
      myScore: myScore ?? this.myScore,
      myWordScore: myWordScore ?? this.myWordScore,
      myTimeBonus: myTimeBonus ?? this.myTimeBonus,
      opponentScore: opponentScore ?? this.opponentScore,
      opponentId: opponentId ?? this.opponentId,
      opponentUsername: opponentUsername ?? this.opponentUsername,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      gameDuration: gameDuration ?? this.gameDuration,
      playerDeadlineAt: playerDeadlineAt ?? this.playerDeadlineAt,
    );
  }

  bool get isWinner => myScore > opponentScore;
  bool get isDraw => myScore == opponentScore;
  int get myPrize => isWinner ? prizePool : 0;

  @override
  String toString() {
    return 'Match(matchId: $matchId, myScore: $myScore, opponentScore: $opponentScore, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Match && other.matchId == matchId;
  }

  @override
  int get hashCode => matchId.hashCode;
}
