import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/firestore_service.dart';

// โหมดคำถาม
enum QuestionMode { listenThenPick, lookThenListen }

class MinigameScreen extends StatefulWidget {
  final String gameType; // "letter" หรือ "vowel"
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

  // โหมดคำถามในแต่ละข้อ
  late QuestionMode _questionMode;

  // ตัวเลือกเสียงที่กำลังเล่น (สำหรับโหมด lookThenListen)
  Map<String, String>? _playingAudioOption;

  String message = "";
  Color feedbackColor = Colors.transparent;
  bool answered = false;

  // ระบบ 10 คำถาม
  int questionCount = 0;
  final int totalQuestions = 10;

  // เก็บ history ของคำถามล่าสุด
  final List<Map<String, String>> _recentQuestions = [];

  // เก็บคำตอบผิด
  final List<Map<String, String>> _wrongQuestions = [];
  bool reviewingWrong = false;

  // เก็บจำนวนคำถามผิดตอนเริ่มรอบแก้ไข
  int maxWrongQuestions = 0;

  // XP & Level (จะบันทึกตอนจบจริง)
  int xp = 0;
  int level = 1;
  int xpForNextLevel = 10;
  bool levelCompleted = false;

  @override
  void initState() {
    super.initState();
    level = widget.startLevel;
    FirestoreService().ensureUserExists();
    _initLetters();
    _generateQuestion();
  }

  void _initLetters() {
    letters = [];
    if (widget.gameType == "letter") {
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
          "audio": "assets/audio/character/Char_$i.m4a",
        });
      }
    } else if (widget.gameType == "vowel") {
      Map<int, List<Map<String, String>>> vowelLevels = {};
      for (int lvl = 1; lvl <= 5; lvl++) {
        int count = (lvl <= 2) ? 28 : 10;

        // กำหนดนามสกุลไฟล์ตามเลเวล
        String ext = (lvl <= 2) ? "jpg" : "png";

        vowelLevels[lvl] = [];
        for (int i = 1; i <= count; i++) {
          vowelLevels[lvl]!.add({
            "char": "V${lvl}_$i",
            "image": "assets/png/vowels/Vowels${lvl}_$i.$ext",
            "audio": "assets/audio/vowels/loud_loud_Vowels${lvl}_$i.m4a",
          });
        }
      }
      letters = vowelLevels[level.clamp(1, 5)] ?? [];
    }
  }

  void _generateQuestion() {
    List<Map<String, String>> sourceList =
        reviewingWrong && _wrongQuestions.isNotEmpty
            ? _wrongQuestions
            : letters;

    if (sourceList.isEmpty) return;

    if (_recentQuestions.length >= sourceList.length) {
      _recentQuestions.clear();
    }

    final random = Random();
    Map<String, String> candidate;

    // เลือกคำถามไม่ซ้ำ
    do {
      candidate = sourceList[random.nextInt(sourceList.length)];
    } while (_recentQuestions.any((q) => q["char"] == candidate["char"]));

    correctLetter = candidate;
    _recentQuestions.add(correctLetter);

    options = [correctLetter];
    while (options.length < 4) {
      final item = letters[random.nextInt(letters.length)];
      if (!options.contains(item)) options.add(item);
    }
    options.shuffle();

   bool allowMixedMode = widget.gameType == "vowel" && level >= 3;

    _questionMode = allowMixedMode && random.nextBool()
    ? QuestionMode.lookThenListen
    : QuestionMode.listenThenPick;

    message = "";
    feedbackColor = Colors.transparent;
    selectedOption = null;
    _playingAudioOption = null;
    answered = false;
    setState(() {});

    // โหมดฟังเสียง → เปิดเสียงอัตโนมัติ
    if (_questionMode == QuestionMode.listenThenPick) {
      _playSound(correctLetter["audio"]!);
    }
  }

  Future<void> _playSound(String path) async {
    await _player.stop();
    await _player.play(AssetSource(path.replaceFirst("assets/", "")));
  }

  void _checkAnswer(Map<String, String> answer) {
    if (answer["char"] == correctLetter["char"]) {
      setState(() {
        message = "✅ ถูกต้อง!";
        feedbackColor = Colors.green.shade400;
        answered = true;
        if (reviewingWrong) {
          _wrongQuestions
              .removeWhere((q) => q["char"] == correctLetter["char"]);
        }
      });
    } else {
      setState(() {
        message = "❌ ผิด!";
        feedbackColor = Colors.red.shade400;
        answered = true;
        if (!reviewingWrong) _wrongQuestions.add(correctLetter);
      });
    }
  }

  // เพิ่มตัวแปรช่วยนับ XP จริง
  int _currentXp = 0;

  void _nextStep() async {
    int xpThisQuestion = 0;
    if (selectedOption != null) {
      if (selectedOption!["char"] == correctLetter["char"]) {
        xpThisQuestion = reviewingWrong ? 8 : 10;
      }
      _currentXp += xpThisQuestion;
    }

    questionCount++;

    if (!reviewingWrong &&
        questionCount >= totalQuestions &&
        _wrongQuestions.isNotEmpty) {
      reviewingWrong = true;
      maxWrongQuestions = _wrongQuestions.length;
      questionCount = 0;
      _recentQuestions.clear();
      _generateQuestion();
      return;
    }

    if (!reviewingWrong && questionCount >= totalQuestions) {
      _finishLevel();
      return;
    }

    if (reviewingWrong && _wrongQuestions.isEmpty) {
      _finishLevel();
      return;
    }

    _generateQuestion();
  }

  void _finishLevel() async {
    setState(() {
      levelCompleted = true;
      xp = _currentXp;
    });

    await FirestoreService().savePracticeResult(
      gameType: widget.gameType,
      sublevel: level,
      itemPlayed: "${widget.gameType} level $level",
      isCorrect: true,
      xpGained: _currentXp,
      aiFeedback: "ผ่านด่านแล้ว",
    );
  }

  Future<bool> _onWillPop() async {
    if (!levelCompleted) {
      bool exit = false;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text("ยืนยันการออก",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "ถ้าออกตอนนี้ คุณจะไม่ได้รับ XP จากการเล่นครั้งนี้",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("ยกเลิก", style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                exit = true;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("ออก", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
      return exit;
    }
    return true;
  }

  String _getLevelName() {
    if (widget.gameType == "letter") return "ตัวอักษร Level $level";
    return "สระ Level $level";
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required List<Color> colors,
    double fontSize = 18,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
    );
  }

  // ── โหมด listenThenPick: ปุ่มลำโพงตรงกลาง (เดิม) ──
  Widget _buildAudioButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 50,
          backgroundColor: Colors.transparent,
          child: IconButton(
            icon: const Icon(Icons.volume_up, size: 50, color: Colors.white),
            onPressed: () => _playSound(correctLetter["audio"]!),
          ),
        ),
      ),
    );
  }

  // ── โหมด lookThenListen: แสดงรูปตรงกลาง ──
  Widget _buildImageDisplay() {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.withOpacity(0.4),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          correctLetter["image"]!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── ตัวเลือกแบบรูปภาพ (โหมด listenThenPick เดิม) ──
  Widget _buildImageOption(Map<String, String> opt) {
    bool isSelected = selectedOption == opt;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: isSelected ? 10 : 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _playSound(opt["audio"]!);
            setState(() {
              selectedOption = opt;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              opt["image"]!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // ── ตัวเลือกแบบปุ่มเสียง (โหมด lookThenListen ใหม่) ──
  Widget _buildAudioOption(Map<String, String> opt) {
    bool isSelected = selectedOption == opt;
    bool isPlaying = _playingAudioOption == opt;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: isSelected ? 10 : 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // กดเพื่อเลือก + เล่นเสียง
            setState(() {
              selectedOption = opt;
              _playingAudioOption = opt;
            });
            await _playSound(opt["audio"]!);
            // หลังเสียงจบ reset สถานะ playing (optional)
            if (mounted) {
              setState(() {
                _playingAudioOption = null;
              });
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPlaying ? Icons.volume_up : Icons.play_circle_fill,
                size: 48,
                color: isSelected ? Colors.white : const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 8),
              Text(
                "กดฟังเสียง",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (await _onWillPop()) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 28),
                      ),
                      Expanded(
                        child: Text(
                          _getLevelName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.yellow, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "$_currentXp XP",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            reviewingWrong ? "รอบแก้ไข" : "คำถาม",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            reviewingWrong
                                ? "เหลือ ${_wrongQuestions.length} ข้อ"
                                : "$questionCount / $totalQuestions ข้อ",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: reviewingWrong
                              ? (_wrongQuestions.isEmpty
                                  ? 1.0
                                  : 1 -
                                      (_wrongQuestions.length /
                                          maxWrongQuestions))
                              : questionCount / totalQuestions,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            reviewingWrong ? Colors.orange : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),

                            // ── Badge บอกโหมด ──
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _questionMode ==
                                          QuestionMode.listenThenPick
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _questionMode ==
                                            QuestionMode.listenThenPick
                                        ? Colors.green.shade200
                                        : Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _questionMode ==
                                              QuestionMode.listenThenPick
                                          ? Icons.hearing
                                          : Icons.image,
                                      size: 16,
                                      color: _questionMode ==
                                              QuestionMode.listenThenPick
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _questionMode ==
                                              QuestionMode.listenThenPick
                                          ? "ฟังเสียง → เลือกภาพ"
                                          : "ดูภาพ → เลือกเสียง",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _questionMode ==
                                                QuestionMode.listenThenPick
                                            ? Colors.green.shade700
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── ส่วนกลาง: ปุ่มเสียง หรือ รูปภาพ ──
                            _questionMode == QuestionMode.listenThenPick
                                ? _buildAudioButton()
                                : _buildImageDisplay(),

                            const SizedBox(height: 30),

                            // ── ตัวเลือก 4 ช่อง ──
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              children: options.map((opt) {
                                return _questionMode ==
                                        QuestionMode.listenThenPick
                                    ? _buildImageOption(opt)
                                    : _buildAudioOption(opt);
                              }).toList(),
                            ),

                            const SizedBox(height: 30),

                            // Feedback Message
                            if (message.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: feedbackColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: feedbackColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: feedbackColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Action Buttons
                            if (selectedOption != null && !answered)
                              _buildGradientButton(
                                onPressed: () => _checkAnswer(selectedOption!),
                                text: "ยืนยัน",
                                icon: Icons.check,
                                colors: const [
                                  Color(0xFF4CAF50),
                                  Color(0xFF388E3C)
                                ],
                              ),

                            if (answered && !levelCompleted)
                              _buildGradientButton(
                                onPressed: _nextStep,
                                text: "ข้อต่อไป",
                                icon: Icons.arrow_forward,
                                colors: const [
                                  Color(0xFF2196F3),
                                  Color(0xFF1976D2)
                                ],
                              ),

                            if (levelCompleted)
                              _buildGradientButton(
                                onPressed: () => Navigator.pop(context),
                                text: "กลับไปเลือกด่าน",
                                icon: Icons.home,
                                colors: const [
                                  Color(0xFF4CAF50),
                                  Color(0xFF388E3C)
                                ],
                              ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}