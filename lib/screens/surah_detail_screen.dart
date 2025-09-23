import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

class _SurahDetailScreenState extends State<SurahDetailScreen>
    with TickerProviderStateMixin {
  int currentAyah = 1;
  String message = "";
  late AudioPlayer _audioPlayer;
  late AudioRecorder _audioRecorder;
  bool started = false;
  bool hasPlayed = false;
  bool showNextButton = false;

  // Recording states
  bool isRecording = false;
  bool hasRecorded = false;
  String? recordedFilePath;
  String? webRecordedData; // For web platform

  int correctCount = 0;
  int wrongCount = 0;

  // เพิ่มตัวแปรสำหรับเก็บ XP
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

    if (isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _initializeRecorder() async {
    // Check and request permissions
    if (await _audioRecorder.hasPermission()) {
      // Permission granted
    } else {
      // Handle permission denied
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
        String fileName = 'recording_${widget.title}_ayah$currentAyah.wav';
        
        if (kIsWeb) {
          // For web platform
          await _audioRecorder.start(const RecordConfig(), path: fileName);
        } else {
          // For mobile platforms
          final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
          final String filePath = '${appDocumentsDir.path}/$fileName';
          
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: filePath,
          );
          
          setState(() {
            recordedFilePath = filePath;
          });
        }

        setState(() {
          isRecording = true;
          hasRecorded = false;
        });
        
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() {
        message = "❌ ไม่สามารถบันทึกเสียงได้";
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      
      _pulseController.stop();
      _pulseController.reset();
      
      if (path != null) {
        if (kIsWeb) {
          setState(() {
            webRecordedData = path;
            hasRecorded = true;
            isRecording = false;
          });
        } else {
          setState(() {
            recordedFilePath = path;
            hasRecorded = true;
            isRecording = false;
          });
        }
        
        setState(() {
          message = "✅ บันทึกเสียงเรียบร้อย!";
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        message = "❌ เกิดข้อผิดพลาดในการบันทึก";
        isRecording = false;
      });
      _pulseController.stop();
    }
  }

  Future<void> _playRecordedAudio() async {
    try {
      await _audioPlayer.stop();
      
      if (kIsWeb && webRecordedData != null) {
        // For web platform - play from memory
        await _audioPlayer.play(UrlSource(webRecordedData!));
      } else if (recordedFilePath != null) {
        // For mobile platforms - play from file
        await _audioPlayer.play(DeviceFileSource(recordedFilePath!));
      }
    } catch (e) {
      debugPrint('Error playing recorded audio: $e');
      setState(() {
        message = "❌ ไม่สามารถเล่นเสียงที่บันทึกได้";
      });
    }
  }

  // แก้ไข _checkAnswer ให้เก็บ XP แต่ไม่บันทึก Firestore ทันที
  void _checkAnswer(bool correct) async {
    await _audioPlayer.stop();

    if (correct) {
      setState(() {
        message = "✅ ถูกต้อง!";
        correctCount++;
        showNextButton = true;
        _currentXp += 10; // เพิ่ม XP แต่ไม่บันทึกลง Firestore ก่อน
      });
    } else {
      setState(() {
        message = "❌ ผิด!";
        wrongCount++;
        showNextButton = true;
        _currentXp += 5; // ให้ XP น้อยกว่าเมื่อตอบผิด
      });
    }

    _slideController.forward();
  }

  void _goToNextAyah() async {
    await _audioPlayer.stop();
    await _audioRecorder.stop();

    if (currentAyah < widget.ayahCount) {
      setState(() {
        currentAyah++;
        message = "";
        hasPlayed = false;
        showNextButton = false;
        hasRecorded = false;
        isRecording = false;
        recordedFilePath = null;
        webRecordedData = null;
      });
      
      _slideController.reset();
      await _playAyah();
    } else {
      // เมื่อจบซูเราะห์ ค่อยบันทึก XP ครั้งเดียว
      await _finishSurah();
      _showSummaryDialog();
    }
  }

  // ฟังก์ชันสำหรับกำหนดเงื่อนไขการให้คะแนนตามซูเราะห์
  String _getResultText() {
    String surahTitle = widget.title.toLowerCase();
    
    if (surahTitle == "al-fatiha") {
      // อัลฟาติหะ: ผิดได้ไม่เกิน 3 ครั้ง
      return wrongCount <= 3 ? "✅ ดีเยี่ยม" : "💪 พยายาม";
    } else if (surahTitle == "al-ikhlas") {
      // อิคลาส: ผิดได้ไม่เกิน 2 ครั้ง
      return wrongCount <= 2 ? "✅ ดีเยี่ยม" : "💪 พยายาม";
    } else {
      // ซูเราะห์อื่น ๆ: ใช้เงื่อนไขเดิม (ไม่ผิดเลย)
      return wrongCount == 0 ? "✅ ดีเยี่ยม" : "💪 พยายาม";
    }
  }

  // เพิ่มฟังก์ชันสำหรับบันทึก XP เมื่อจบซูเราะห์
  Future<void> _finishSurah() async {
    setState(() {
      levelCompleted = true;
    });

    String resultText = _getResultText(); // ใช้ฟังก์ชันใหม่

    // บันทึก XP ครั้งเดียวเมื่อจบซูเราะห์
    await FirestoreService().addXpOnce(
      _currentXp,
      sublevel: 1, // หรือจะกำหนดเป็นเลขอื่นตามซูเราะห์
      resultText: resultText,
      levelName: "การอ่านซูเราะห์",
      gameType: "surah", // ระบุประเภทเป็น surah
    );
  }

  // ฟังก์ชันสำหรับยืนยันการออก
  Future<bool> _showExitConfirmation() async {
    if (!started) {
      return true; // ถ้ายังไม่เริ่มฝึก ให้ออกได้เลย
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("ยืนยันการออก", style: TextStyle(fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("ออก", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSummaryDialog() {
    String resultText = _getResultText(); // ใช้ฟังก์ชันเดียวกัน
    Color resultColor = resultText.contains("✅") ? Colors.green : Colors.orange;
    IconData resultIcon = resultText.contains("✅") ? Icons.celebration : Icons.fitness_center;
    
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              // แสดงผลลัพธ์ตามซูเราะห์
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
              _buildResultRow("✅ อ่านถูก", correctCount, Colors.green),
              const SizedBox(height: 10),
              _buildResultRow("❌ อ่านผิด", wrongCount, Colors.red),
              const SizedBox(height: 15),
              const Divider(),
              Text(
                "รวมทั้งหมด: ${widget.ayahCount} อายะห์",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // แสดงเงื่อนไขการให้คะแนน
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getScoringInfo(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              // แสดง XP ที่ได้รับ
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
                correctCount = 0;
                wrongCount = 0;
                message = "";
                hasPlayed = false;
                showNextButton = false;
                started = false;
                hasRecorded = false;
                isRecording = false;
                recordedFilePath = null;
                webRecordedData = null;
                _currentXp = 0; // รีเซ็ต XP
                levelCompleted = false; // รีเซ็ตสถานะ
              });
              _slideController.reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("ฝึกใหม่", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันแสดงข้อมูลเงื่อนไขการให้คะแนน
  String _getScoringInfo() {
    String surahTitle = widget.title.toLowerCase();
    
    if (surahTitle == "al-fatiha") {
      return "เงื่อนไข: ผิดได้ไม่เกิน 3 ครั้ง = ดีเยี่ยม";
    } else if (surahTitle == "al-ikhlas") {
      return "เงื่อนไข: ผิดได้ไม่เกิน 2 ครั้ง = ดีเยี่ยม";
    } else {
      return "เงื่อนไข: ต้องอ่านถูกทุกอายะห์ = ดีเยี่ยม";
    }
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
    required VoidCallback onPressed,
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
          style: TextStyle(fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: minimumSize,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
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

    // สร้าง path รูป (อายะห์ 2 หลัก เช่น 01, 02)
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
                Color(0xFF4CAF50), // สีเขียว
                Color(0xFF81C784), // สีเขียวอ่อน
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (await _showExitConfirmation()) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
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
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
                
                // Progress Section - Updated to match MinigameScreen style
                if (started) // Only show progress when started
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "$currentAyah / ${widget.ayahCount} อายะห์",
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
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                          : _buildPracticeScreen(progress, imagePath),
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
          child: const Icon(
            Icons.menu_book,
            size: 80,
            color: Colors.white,
          ),
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
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 50),
        _buildGradientButton(
          onPressed: () {
            setState(() {
              started = true;
            });
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

  Widget _buildPracticeScreen(double progress, String imagePath) {
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
                            Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("ไม่พบรูปภาพ", style: TextStyle(color: Colors.grey)),
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
                
                // Recording Button with Animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isRecording ? _pulseAnimation.value : 1.0,
                      child: _buildGradientButton(
                        onPressed: isRecording ? _stopRecording : _startRecording,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "กำลังบันทึก...",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
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

          // Answer Buttons
          if (!showNextButton) ...[
            Row(
              children: [
                Expanded(
                  child: _buildGradientButton(
                    onPressed: () => _checkAnswer(true),
                    text: "อ่านถูก",
                    icon: Icons.check_circle,
                    colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
                    minimumSize: const Size(0, 50),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildGradientButton(
                    onPressed: () => _checkAnswer(false),
                    text: "อ่านผิด",
                    icon: Icons.cancel,
                    colors: const [Colors.red, Colors.redAccent],
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ],
            ),
          ],

          // Next Button with Animation
          if (showNextButton) ...[
            SlideTransition(
              position: _slideAnimation,
              child: _buildGradientButton(
                onPressed: _goToNextAyah,
                text: currentAyah >= widget.ayahCount ? "ดูผลลัพธ์" : "ถัดไป",
                icon: currentAyah >= widget.ayahCount ? Icons.assessment : Icons.arrow_forward,
                colors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
                fontSize: 18,
                minimumSize: const Size(200, 50),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Message Display
          if (message.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: message.contains("✅") 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: message.contains("✅") 
                    ? Colors.green.withOpacity(0.3) 
                    : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: message.contains("✅") ? Colors.green[700] : Colors.red[700],
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