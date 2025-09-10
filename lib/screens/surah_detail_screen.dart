import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/firestore_service.dart';

class SurahDetailScreen extends StatefulWidget {
  final String title;
  final int ayahCount;

  const SurahDetailScreen({
    super.key,
    required this.title,
    required this.ayahCount,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  int currentAyah = 1;
  String message = "";
  late AudioPlayer _audioPlayer;
  bool started = false;
  bool hasPlayed = false;
  bool showNextButton = false;

  int correctCount = 0;
  int wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  Future<void> _playAyah() async {
    String prefix = widget.title.toLowerCase();

    if (prefix == "al-fatiha") prefix = "fatiha";
    if (prefix == "al-ikhlas") prefix = "ikhlas";

    String path = "audio/$prefix/${prefix}_ayah$currentAyah.wav";

    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(path));

    setState(() {
      hasPlayed = true;
    });
  }

  void _checkAnswer(bool correct) async {
    // หยุดเสียงก่อนแสดงผล
    await _audioPlayer.stop();

    if (correct) {
      setState(() {
        message = "✅ ถูกต้อง!";
        correctCount++;
        showNextButton = true;
      });
      await FirestoreService().savePracticeResult(widget.title, "✅ ดีเยี่ยม");
    } else {
      setState(() {
        message = "❌ ผิด!";
        wrongCount++;
        showNextButton = true;
      });
      await FirestoreService().savePracticeResult(widget.title, "❌ พยายามเข้า");
    }
  }

  void _goToNextAyah() async {
    // หยุดเสียงก่อนจะไปอายะห์ถัดไป
    await _audioPlayer.stop();

    if (currentAyah < widget.ayahCount) {
      setState(() {
        currentAyah++;
        message = "";
        hasPlayed = false;
        showNextButton = false;
      });
      await _playAyah(); // เล่นเสียงใหม่
    } else {
      _showSummaryDialog();
    }
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🎉 สรุปผลการฝึก"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("✅ อ่านถูก: $correctCount"),
            Text("❌ อ่านผิด: $wrongCount"),
            const SizedBox(height: 10),
            Text("รวมทั้งหมด: ${widget.ayahCount} อายะห์"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับหน้าแรก
            },
            child: const Text("กลับหน้าแรก"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                currentAyah = 1;
                correctCount = 0;
                wrongCount = 0;
                message = "";
                hasPlayed = false;
                showNextButton = false;
                started = false;
              });
            },
            child: const Text("ฝึกใหม่"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = currentAyah / widget.ayahCount;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: !started
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "ซุเราะห์: ${widget.title}",
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          started = true;
                        });
                      },
                      child: const Text("เริ่มฝึก",
                          style: TextStyle(fontSize: 20)),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 🔹 Progress bar
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      color: Colors.green,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "อายะห์ที่ $currentAyah / ${widget.ayahCount}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _playAyah,
                      icon: const Icon(Icons.volume_up),
                      label: Text(
                        hasPlayed ? "เล่นซ้ำ" : "ฟังอายะห์นี้",
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ปุ่มอ่านถูก/ผิด
                    if (!showNextButton) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _checkAnswer(true),
                            child: const Text("อ่านถูก",
                                style: TextStyle(fontSize: 18)),
                          ),
                          ElevatedButton(
                            onPressed: () => _checkAnswer(false),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text("อ่านผิด",
                                style: TextStyle(fontSize: 18)),
                          ),
                        ],
                      ),
                    ],

                    // ปุ่มถัดไป
                    if (showNextButton) ...[
                      ElevatedButton(
                        onPressed: _goToNextAyah,
                        child:
                            const Text("ถัดไป", style: TextStyle(fontSize: 18)),
                      ),
                    ],

                    const SizedBox(height: 30),
                    Text(
                      message,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
