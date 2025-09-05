class Stage {
  final String name;        // "alphabet", "vowel1", ...
  final String displayName; // "หมวดอักษร", "สระ 1", ...
  final int maxQuestions;
  final int passScore;      // คะแนนขั้นต่ำปลดล็อก stage ต่อไป
  bool unlocked;

  Stage({
    required this.name,
    required this.displayName,
    required this.maxQuestions,
    required this.passScore,
    this.unlocked = false,
  });
}
