class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final int points;
  final bool isSecret;
  final bool isUnlocked;
  
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.points,
    this.isSecret = false,
    this.isUnlocked = false,
  });

  factory Achievement.fromJson(Map<String, dynamic> json, {bool unlocked = false}) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['icon_name'],
      points: json['points'] ?? 0,
      isSecret: json['secret'] ?? false,
      isUnlocked: unlocked,
    );
  }
}
