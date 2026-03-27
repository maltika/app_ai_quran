import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/model_service.dart';

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

class _SurahDetailScreenState extends State<SurahDetailScreen>
    with TickerProviderStateMixin {
  int currentAyah = 1;
  String message = "";
  String recordMessage = ""; // 🔴 แยก message บันทึกเสียงออกจากผลประเมิน
  late AudioPlayer _audioPlayer;
  late AudioRecorder _audioRecorder;
  bool started = false;
  bool hasPlayed = false;
  bool showNextButton = false;

  // Recording states
  bool isRecording = false;
  bool hasRecorded = false;
  String? recordedFilePath;
  String? webRecordedData;

  // ระบบประเมินผล 3 ระดับ
  int excellentCount = 0;
  int goodCount = 0;
  int tryCount = 0;

  // AI Analysis
  bool isAnalyzing = false;

  // XP
  int _currentXp = 0;
  bool levelCompleted = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioRecorder = AudioRecorder();
    _initializeRecorder();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  Future<void> _initializeRecorder() async {
    if (await _audioRecorder.hasPermission()) {
      // Permission granted
    } else {
      debugPrint('Recording permission denied');
    }
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

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath =
            '${tempDir.path}/${widget.title}_ayah$currentAyah.wav';

        final file = File(filePath);
        if (file.existsSync()) await file.delete();

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );

        setState(() {
          recordedFilePath = filePath;
          isRecording = true;
          hasRecorded = false;
          recordMessage = ""; // 🔴 ล้าง record message
        });
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      setState(() => recordMessage = "❌ ไม่สามารถบันทึกเสียงได้");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      _pulseController.stop();
      _pulseController.reset();

      if (path != null) {
        final file = File(path);
        final int size = await file.length();

        setState(() {
          recordedFilePath = path;
          hasRecorded = size > 0;
          isRecording = false;
          // 🔴 แสดงใน recordMessage แทน message
          recordMessage = size > 0
              ? "✅ บันทึกเสียงเรียบร้อย!"
              : "⚠️ เสียงเบาเกินไปหรือไมค์ไม่ติด";
        });
      }
    } catch (e) {
      debugPrint("❌ หยุดบันทึกไม่สำเร็จ: $e");
    }
  }

  Future<void> _playRecordedAudio() async {
    try {
      await _audioPlayer.stop();
      if (kIsWeb && webRecordedData != null) {
        await _audioPlayer.play(UrlSource(webRecordedData!));
      } else if (recordedFilePath != null) {
        await _audioPlayer.play(DeviceFileSource(recordedFilePath!));
      }
    } catch (e) {
      setState(() => recordMessage = "❌ ไม่สามารถเล่นเสียงที่บันทึกได้");
    }
  }

  /// วิเคราะห์เสียงด้วย AI
  Future<void> _analyzeWithAI() async {
    setState(() => isAnalyzing = true);
    try {
      final result = await ModelService.instance.predict(recordedFilePath!);
      final level = result['level'] as String;
      final confidence = (result['confidence'] as double) * 100;

      debugPrint("🔍 confidence: ${confidence.toStringAsFixed(1)}%");
      _checkAnswer(level);
    } catch (e, stackTrace) {
      debugPrint('❌ AI Error: $e');
      debugPrint('❌ Stack: $stackTrace');
      setState(() => message = "❌ Error: $e");
    } finally {
      setState(() => isAnalyzing = false);
    }
  }

  /// ตรวจสอบคำตอบและให้คะแนน
  void _checkAnswer(String level) async {
    await _audioPlayer.stop();

    setState(() {
      // 🔴 unclear/silent → บังคับบันทึกใหม่ (ล้าง hasRecorded ด้วย)
      if (level == 'silent' || level == 'isSilence') {
        showNextButton = false;
        hasRecorded = false;
        recordedFilePath = null;
        recordMessage = "";
        message = "🔇 ไม่ได้ยินเสียง กรุณาลองบันทึกใหม่อีกครั้ง";
        return;
      }

      if (level == 'unclear') {
        showNextButton = false;
        hasRecorded = false;
        recordedFilePath = null;
        recordMessage = "";
        message = "🎤 เสียงไม่ชัดเจน ลองอ่านให้ดังขึ้นแล้วลองใหม่";
        return;
      }

      showNextButton = true;
      switch (level) {
        case 'excellent':
          excellentCount++;
          _currentXp += 10;
          message = "🌟 เก่งมาก!";
          break;
        case 'good':
          goodCount++;
          _currentXp += 5;
          message = "👍 พอใช้!";
          break;
        default:
          tryCount++;
          _currentXp += 2;
          message = "💪 พยายามเข้า!";
      }
    });
    _slideController.forward();
  }

  void _goToNextAyah() async {
    await _audioPlayer.stop();
    await _audioRecorder.stop();

    if (currentAyah < widget.ayahCount) {
      setState(() {
        currentAyah++;
        message = "";
        recordMessage = ""; // 🔴 ล้างด้วย
        hasPlayed = false;
        showNextButton = false;
        hasRecorded = false;
        isRecording = false;
        recordedFilePath = null;
        webRecordedData = null;
      });

      _slideController.reset();
      await _playAyah(); // 🟡 เล่นอัตโนมัติเมื่อไปอายะห์ถัดไป (มีอยู่แล้ว ยืนยันว่าทำงาน)
    } else {
      await _finishSurah();
      _showSummaryDialog();
    }
  }

  // 🟡 weighted score แทน excellentPercent
  String _getResultText() {
    int total = excellentCount + goodCount + tryCount;
    if (total == 0) return "💪 พยายาม";

    double avgXp = _currentXp / total;

    if (avgXp >= 8) return "✅ ดีเยี่ยม";
    if (avgXp >= 5) return "👍 พอใช้";
    return "💪 พยายาม";
  }

  Future<void> _finishSurah() async {
    setState(() => levelCompleted = true);

    await FirestoreService().addXpOnce(
      _currentXp,
      sublevel: 1,
      resultText: _getResultText(),
      levelName: "การอ่านซูเราะห์",
      gameType: "surah",
    );
  }

  Future<bool> _showExitConfirmation() async {
    if (!started) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
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
              "คุณต้องการออกจากการฝึกหรือไม่?\nข้อมูลการฝึกจะไม่ถูกบันทึก",
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("ยกเลิก", style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
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
        ) ??
        false;
  }

  void _showSummaryDialog() {
    String resultText = _getResultText();
    Color resultColor = resultText.contains("✅")
        ? Colors.green
        : resultText.contains("👍")
            ? Colors.orange
            : Colors.deepOrange;
    IconData resultIcon = resultText.contains("✅")
        ? Icons.celebration
        : Icons.fitness_center;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: resultText.contains("✅")
                  ? [Colors.green, Colors.green.shade700]
                  : [Colors.orange, Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(resultIcon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Text(
                "สรุปผลการฝึก",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.grey[50],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: resultColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(resultIcon, color: resultColor, size: 32),
                    const SizedBox(width: 10),
                    Text(
                      resultText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildResultRow("🌟 เก่งมาก", excellentCount, Colors.green),
              const SizedBox(height: 10),
              _buildResultRow("👍 พอใช้", goodCount, Colors.orange),
              const SizedBox(height: 10),
              _buildResultRow("💪 พยายามเข้า", tryCount, Colors.red),
              const SizedBox(height: 15),
              const Divider(),
              Text(
                "รวมทั้งหมด: ${widget.ayahCount} อายะห์",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // 🟡 แสดง XP ที่ได้รับ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.yellow, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "ได้รับ $_currentXp XP",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("กลับหน้าแรก", style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                currentAyah = 1;
                excellentCount = 0;
                goodCount = 0;
                tryCount = 0;
                message = "";
                recordMessage = "";
                hasPlayed = false;
                showNextButton = false;
                started = false;
                hasRecorded = false;
                isRecording = false;
                isAnalyzing = false;
                recordedFilePath = null;
                webRecordedData = null;
                _currentXp = 0;
                levelCompleted = false;
              });
              _slideController.reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("ฝึกใหม่", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required List<Color> colors,
    double fontSize = 16,
    Size minimumSize = const Size(200, 45),
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
          minimumSize: minimumSize,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = currentAyah / widget.ayahCount;

    String surahPrefix = widget.title.toLowerCase().replaceAll("al-", "");
    String ayahStr = currentAyah.toString().padLeft(2, '0');
    String imagePath = "assets/png/surah/$surahPrefix$ayahStr.png";

    return WillPopScope(
      onWillPop: _showExitConfirmation,
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
                // App Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (await _showExitConfirmation()) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 28),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 🟢 XP สะสมมุมบนขวา
                      if (started)
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
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Progress Bar
                if (started)
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
                            const Text(
                              "อายะห์",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "$currentAyah / ${widget.ayahCount} อายะห์",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
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
                      child: !started
                          ? _buildStartScreen()
                          : _buildPracticeScreen(imagePath),
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

  Widget _buildStartScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
          child: const Icon(Icons.menu_book, size: 80, color: Colors.white),
        ),
        const SizedBox(height: 40),
        Text(
          "ซุเราะห์ ${widget.title}",
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          "${widget.ayahCount} อายะห์",
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
        const SizedBox(height: 50),
        _buildGradientButton(
          // 🔴 กด "เริ่มฝึก" → เล่นเสียงอัตโนมัติ
          onPressed: () async {
            setState(() => started = true);
            await _playAyah();
          },
          text: "เริ่มฝึก",
          icon: Icons.play_arrow,
          colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
          fontSize: 20,
          minimumSize: const Size(200, 60),
        ),
      ],
    );
  }

  Widget _buildPracticeScreen(String imagePath) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 30),

          // Ayah Image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(15),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("ไม่พบรูปภาพ",
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Play Audio Button
          _buildGradientButton(
            onPressed: _playAyah,
            text: hasPlayed ? "เล่นซ้ำ" : "ฟังอายะห์นี้",
            icon: Icons.volume_up,
            colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
            fontSize: 18,
          ),
          const SizedBox(height: 30),

          // Recording Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.green.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: Colors.green[700], size: 24),
                    const SizedBox(width: 10),
                    Text(
                      "บันทึกเสียงของคุณ",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Recording Button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isRecording ? _pulseAnimation.value : 1.0,
                      child: _buildGradientButton(
                        onPressed:
                            isRecording ? _stopRecording : _startRecording,
                        text: isRecording ? "หยุดบันทึก" : "เริ่มบันทึก",
                        icon: isRecording ? Icons.stop : Icons.mic,
                        colors: isRecording
                            ? [Colors.red, Colors.redAccent]
                            : [Colors.orange, Colors.deepOrange],
                        fontSize: 16,
                      ),
                    );
                  },
                ),

                if (isRecording) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record,
                            color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text("กำลังบันทึก...",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],

                // 🔴 recordMessage แยกออกมาต่างหาก
                if (recordMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    recordMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: recordMessage.contains("✅")
                          ? Colors.green[600]
                          : Colors.orange[700],
                    ),
                  ),
                ],

                if (hasRecorded && !isRecording) ...[
                  const SizedBox(height: 15),
                  _buildGradientButton(
                    onPressed: _playRecordedAudio,
                    text: "ฟังเสียงที่บันทึก",
                    icon: Icons.play_arrow,
                    colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),

          // AI Analysis Button
          // 🟡 disable ถ้ายังไม่เคยฟังอายะห์เลย
          if (!showNextButton) ...[
            _buildGradientButton(
              onPressed: (isAnalyzing || isRecording || !hasRecorded || !hasPlayed)
                  ? null
                  : _analyzeWithAI,
              text: isAnalyzing
                  ? "กำลังวิเคราะห์..."
                  : !hasPlayed
                      ? "ฟังอายะห์ก่อนนะ"
                      : "ประเมินด้วย AI",
              icon: isAnalyzing
                  ? Icons.hourglass_top
                  : !hasPlayed
                      ? Icons.hearing
                      : Icons.psychology,
              colors: (isAnalyzing || !hasPlayed)
                  ? [Colors.grey, Colors.grey]
                  : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
              minimumSize: const Size(220, 55),
            ),
          ],

          // Next Button
          if (showNextButton) ...[
            SlideTransition(
              position: _slideAnimation,
              child: _buildGradientButton(
                onPressed: _goToNextAyah,
                text:
                    currentAyah >= widget.ayahCount ? "ดูผลลัพธ์" : "ถัดไป",
                icon: currentAyah >= widget.ayahCount
                    ? Icons.assessment
                    : Icons.arrow_forward,
                colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
                fontSize: 18,
                minimumSize: const Size(200, 50),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ผลประเมิน AI
          if (message.isNotEmpty) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: message.contains("🌟") || message.contains("👍")
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: message.contains("🌟") || message.contains("👍")
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: message.contains("🌟") || message.contains("👍")
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}