class UserModel {
  String username;
  int totalXp;
  int level;
  List<String> badges;
  Map<String, dynamic> completedStages;

  UserModel({
    required this.username,
    this.totalXp = 0,
    this.level = 1,
    this.badges = const [],
    this.completedStages = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      username: map['username'] ?? '',
      totalXp: map['totalXp'] ?? 0,
      level: map['level'] ?? 1,
      badges: List<String>.from(map['badges'] ?? []),
      completedStages: Map<String, dynamic>.from(map['completedStages'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'totalXp': totalXp,
      'level': level,
      'badges': badges,
      'completedStages': completedStages,
    };
  }
}
