class Lobby {
  final String lobbyId;
  final String name;
  final int entryFee; // in gems
  final int prizePool; // in gems
  final int maxPlayers;
  final int currentPlayers;
  final int estimatedWaitTime; // in seconds
  final String difficulty; // easy, medium, hard
  final int boardSize; // 4 or 5
  final int gameDuration; // in seconds
  final bool isActive;
  final DateTime createdAt;

  const Lobby({
    required this.lobbyId,
    required this.name,
    required this.entryFee,
    required this.prizePool,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.estimatedWaitTime,
    required this.difficulty,
    required this.boardSize,
    required this.gameDuration,
    required this.isActive,
    required this.createdAt,
  });

  factory Lobby.fromJson(Map<String, dynamic> json) {
    return Lobby(
      lobbyId: json['lobbyId'] as String,
      name: json['name'] as String,
      entryFee: json['entryFee'] as int,
      prizePool: json['prizePool'] as int,
      maxPlayers: json['maxPlayers'] as int,
      currentPlayers: json['currentPlayers'] as int,
      estimatedWaitTime: json['estimatedWaitTime'] as int,
      difficulty: json['difficulty'] as String,
      boardSize: json['boardSize'] as int,
      gameDuration: json['gameDuration'] as int,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lobbyId': lobbyId,
      'name': name,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'estimatedWaitTime': estimatedWaitTime,
      'difficulty': difficulty,
      'boardSize': boardSize,
      'gameDuration': gameDuration,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Lobby copyWith({
    String? lobbyId,
    String? name,
    int? entryFee,
    int? prizePool,
    int? maxPlayers,
    int? currentPlayers,
    int? estimatedWaitTime,
    String? difficulty,
    int? boardSize,
    int? gameDuration,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Lobby(
      lobbyId: lobbyId ?? this.lobbyId,
      name: name ?? this.name,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      estimatedWaitTime: estimatedWaitTime ?? this.estimatedWaitTime,
      difficulty: difficulty ?? this.difficulty,
      boardSize: boardSize ?? this.boardSize,
      gameDuration: gameDuration ?? this.gameDuration,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isFull => currentPlayers >= maxPlayers;
  bool get isAvailable => isActive && !isFull;
  
  String get formattedEntryFee => '$entryFee gems';
  String get formattedPrizePool => '$prizePool gems';
  String get formattedGemPool => '$prizePool gems';
  
  String get formattedWaitTime {
    if (estimatedWaitTime < 60) {
      return '${estimatedWaitTime}s';
    } else {
      final minutes = estimatedWaitTime ~/ 60;
      return '${minutes}m';
    }
  }

  @override
  String toString() {
    return 'Lobby(lobbyId: $lobbyId, name: $name, entryFee: $formattedEntryFee, prizePool: $formattedPrizePool)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lobby && other.lobbyId == lobbyId;
  }

  @override
  int get hashCode => lobbyId.hashCode;
}
