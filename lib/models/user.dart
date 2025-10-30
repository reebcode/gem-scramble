class User {
  final String id;
  final String username;
  final int gems; // primary currency
  final int bonusGems; // promotional gems
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool needsUsername;

  const User({
    required this.id,
    required this.username,
    required this.gems,
    required this.bonusGems,
    required this.createdAt,
    required this.lastActiveAt,
    this.needsUsername = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['deviceId'] ?? '').toString(),
      username: (json['username'] ?? json['deviceId'] ?? 'Player').toString(),
      gems: (json['gemBalance'] ?? json['gems'] ?? 0) as int,
      bonusGems: (json['bonusGems'] ?? 0) as int,
      createdAt: DateTime.parse(
          (json['createdAt'] ?? DateTime.now().toIso8601String()) as String),
      lastActiveAt: DateTime.parse(
          (json['lastActiveAt'] ?? DateTime.now().toIso8601String()) as String),
      needsUsername: (json['needsUsername'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'gems': gems,
      'bonusGems': bonusGems,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'needsUsername': needsUsername,
    };
  }

  User copyWith({
    String? id,
    String? username,
    int? gems,
    int? bonusGems,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? needsUsername,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      gems: gems ?? this.gems,
      bonusGems: bonusGems ?? this.bonusGems,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      needsUsername: needsUsername ?? this.needsUsername,
    );
  }

  int get totalGems => gems + bonusGems;

  String get formattedGemBalance => '$gems gems';
  String get formattedBonusGemBalance => '$bonusGems bonus gems';
  String get formattedTotalGemBalance => '$totalGems gems';

  @override
  String toString() {
    return 'User(id: $id, username: $username, gems: $gems, bonusGems: $bonusGems)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
