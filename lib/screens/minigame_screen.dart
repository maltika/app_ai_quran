import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/firestore_service.dart';

class MinigameScreen extends StatefulWidget {
  final String gameType; // "alphabet" หรือ "vowel"
  final int startLevel; // ด่านย่อยที่เริ่ม
  const MinigameScreen(
      {super.key, required this.gameType, this.startLevel = 1});

  @override
  State<MinigameScreen> createState() => _MinigameScreenState();
}

class _MinigameScreenState extends State<MinigameScreen> {
  final AudioPlayer _player = AudioPlayer();

  late List<Map<String, String>> letters;
  late Map<String, String> correctLetter;
  late List<Map<String, String>> options;

  Map<String, String>? selectedOption;

  String message = "";
  Color feedbackColor = Colors.transparent;
  bool answered = false;

  // XP & Level
  int xp = 0;
  int level = 1;
  int xpForNextLevel = 10;
  bool levelCompleted = false;

  // ✅ เก็บ history ของคำถามล่าสุด
  final List<Map<String, String>> _recentQuestions = [];

  // ✅ เก็บคำตอบผิดและตรวจสอบรอบแก้คำตอบผิด
  final List<Map<String, String>> _wrongQuestions = [];
  bool reviewingWrong = false;

  @override
  void initState() {
    super.initState();
    level = widget.startLevel; // เริ่มจากด่านย่อยที่เลือก
    _initLetters();
    _generateQuestion();
  }

  void _initLetters() {
    letters = [];
    if (widget.gameType == "alphabet") {
      int start = 1, end = 10;
      if (level == 1) {
        start = 1;
        end = 10;
      } else if (level == 2) {
        start = 11;
        end = 20;
      } else if (level == 3) {
        start = 21;
        end = 29;
      }
      for (int i = start; i <= end; i++) {
        letters.add({
          "char": "อักษร $i",
          "image": "assets/png/character/char_$i.png",
          "audio": "assets/audio/character/char_$i.m4a",
        });
      }
    } else if (widget.gameType == "vowel") {
      Map<int, List<Map<String, String>>> vowelLevels = {};
      for (int lvl = 1; lvl <= 5; lvl++) {
        int count = (lvl <= 2) ? 28 : 10;
        vowelLevels[lvl] = [];
        for (int i = 1; i <= count; i++) {
          vowelLevels[lvl]!.add({
            "char": "V$lvl\_$i",
            "image":
                "assets/png/vowels/Vowels$lvl\_$i${(lvl <= 2 ? '.jpg' : '.png')}",
            "audio": "assets/audio/vowels/loud_loud_Vowels$lvl\_$i.m4a",
          });
        }
      }
      letters = vowelLevels[level.clamp(1, 5)] ?? [];
    }
  }

  void _generateQuestion() {
    List<Map<String, String>> sourceList = letters;

    if (reviewingWrong && _wrongQuestions.isNotEmpty) {
      sourceList = _wrongQuestions;
    } else if (letters.isEmpty || levelCompleted) return;

    // รีเซ็ต history ถ้าใช้ครบทุกคำถาม
    if (_recentQuestions.length >= sourceList.length) {
      _recentQuestions.clear();
    }

    final random = Random();
    Map<String, String> candidate;

    // เลือกโจทย์ที่ไม่เคยใช้มาก่อน
    do {
      candidate = sourceList[random.nextInt(sourceList.length)];
    } while (_recentQuestions.any((q) => q["char"] == candidate["char"]));

    correctLetter = candidate;
    _recentQuestions.add(correctLetter);

    // สร้าง options
    options = [correctLetter];
    while (options.length < 4) {
      final item = letters[random.nextInt(letters.length)];
      if (!options.contains(item)) options.add(item);
    }
    options.shuffle();

    // รีเซ็ตสถานะปุ่มและข้อความ
    message = "";
    feedbackColor = Colors.transparent;
    selectedOption = null;
    answered = false;
    setState(() {});

    // เล่นเสียงโจทย์อัตโนมัติ
    _playSound(correctLetter["audio"]!);
  }

  Future<void> _playSound(String path) async {
    await _player.stop();
    await _player.play(AssetSource(path.replaceFirst("assets/", "")));
  }

  void _checkAnswer(Map<String, String> answer) async {
    if (answer["char"] == correctLetter["char"]) {
      setState(() {
        message = "✅ ถูกต้อง!";
        feedbackColor = Colors.green.shade400;
        xp++;
        if (xp >= xpForNextLevel) {
          levelCompleted = true;
        }
        answered = true;
        if (reviewingWrong) {
          _wrongQuestions.removeWhere((q) => q["char"] == correctLetter["char"]);
        }
      });
      await FirestoreService()
          .savePracticeResult(widget.gameType, "✅ ดีเยี่ยม");
    } else {
      setState(() {
        message = "❌ ผิด!";
        feedbackColor = Colors.red.shade400;
        answered = true;
        if (!reviewingWrong) _wrongQuestions.add(correctLetter);
      });
      await FirestoreService()
          .savePracticeResult(widget.gameType, "⚠️ พยายามเข้า");
    }
  }

  void _nextLevel() {
    xp = 0;
    levelCompleted = false;
    reviewingWrong = false;
    _wrongQuestions.clear();
    if (widget.gameType == "alphabet") {
      if (level < 3) level++;
    } else if (widget.gameType == "vowel") {
      if (level < 5) level++;
    }
    _initLetters();
    _generateQuestion();
  }

  String _getLevelName() {
    if (widget.gameType == "alphabet") return "ตัวอักษร Level $level";
    return "Vowels$level";
  }

  @override
  Widget build(BuildContext context) {
    double progress = xp / xpForNextLevel;

    return Scaffold(
      backgroundColor: feedbackColor.withOpacity(0.05),
      appBar: AppBar(
        title: Text(_getLevelName()),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress Bar
            Row(
              children: [
                Text("Lv. $level",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ),
                Text("$xp / $xpForNextLevel XP",
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 40),

            // ปุ่มเล่นเสียงหลัก (คำถาม)
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.blue.shade100,
              child: IconButton(
                icon: const Icon(Icons.volume_up,
                    size: 45, color: Colors.deepPurple),
                onPressed: () => _playSound(correctLetter["audio"]!),
              ),
            ),
            const SizedBox(height: 40),

            // Grid การ์ด
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: options.map((opt) {
                  bool isSelected = selectedOption == opt;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color:
                              isSelected ? Colors.blue : Colors.grey.shade300,
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        _playSound(opt["audio"]!); // ✅ กดการ์ด = เล่นเสียง
                        setState(() {
                          selectedOption = opt; // ✅ เลือกการ์ด
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(opt["image"]!, fit: BoxFit.contain),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Feedback
            if (message.isNotEmpty)
              Text(
                message,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: feedbackColor),
              ),

            const SizedBox(height: 20),

            // ปุ่มกดตอบ
            if (selectedOption != null && !answered)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  _checkAnswer(selectedOption!);
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text("ยืนยัน",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),

            // ปุ่มไปข้อต่อไป
            if (answered && !levelCompleted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  _generateQuestion();
                },
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text("ข้อต่อไป",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),

            // ปุ่ม Next Level / รอบแก้คำตอบผิด
            if (levelCompleted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  if (_wrongQuestions.isNotEmpty && !reviewingWrong) {
                    // เริ่มรอบแก้คำตอบผิด
                    reviewingWrong = true;
                    _recentQuestions.clear();
                    _generateQuestion();
                  } else {
                    // Next Level จริง ๆ
                    _nextLevel();
                  }
                },
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: Text(
                    reviewingWrong && _wrongQuestions.isNotEmpty
                        ? "แก้คำตอบผิด"
                        : "Next Level",
                    style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
