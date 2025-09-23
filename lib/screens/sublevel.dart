import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'minigame_screen.dart';
import 'surah_screen.dart'; // ต้อง import ด้วยนะ

class SublevelScreen extends StatelessWidget {
  final String gameType;
  final int maxLevel;

  const SublevelScreen({super.key, required this.gameType, required this.maxLevel});

  String _getGameTitle() {
    switch (gameType) {
      case 'alphabet':
        return 'เรียนรู้ตัวอักษร';
      case 'vowel':
        return 'เรียนรู้สระ';
      case 'surah':
        return 'นครแห่งอายะห์';
      default:
        return 'เลือกด่านย่อย';
    }
  }

  IconData _getGameIcon() {
    switch (gameType) {
      case 'alphabet':
        return Icons.text_fields;
      case 'vowel':
        return Icons.record_voice_over;
      case 'surah':
        return Icons.menu_book;
      default:
        return Icons.games;
    }
  }

  String _getLevelName(int sublevel) {
    switch (gameType) {
      case 'alphabet':
        if (sublevel == 1) return 'ตัวอักษร 1-10';
        if (sublevel == 2) return 'ตัวอักษร 11-20';
        if (sublevel == 3) return 'ตัวอักษร 21-29';
        return 'ด่าน $sublevel';
      case 'vowel':
        return 'สระระดับ $sublevel';
      default:
        return 'ด่าน $sublevel';
    }
  }

  String _getLevelDescription(int sublevel) {
    switch (gameType) {
      case 'alphabet':
        if (sublevel == 1) return 'เรียนรู้ตัวอักษรพื้นฐาน';
        if (sublevel == 2) return 'ตัวอักษรระดับกลาง';
        if (sublevel == 3) return 'ตัวอักษรระดับสูง';
        return 'ฝึกฝนตัวอักษร';
      case 'vowel':
        return 'เรียนรู้เสียงสระ';
      default:
        return 'ฝึกฝนความรู้';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        _getGameTitle(),
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

              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getGameIcon(),
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "เลือกด่านที่ต้องการฝึก",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirestoreService().getUserStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                        );
                      }

                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final unlocked = data["unlockedSublevel"] ?? 1;

                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Levels List (แบบ Surah)
                            Expanded(
                              child: ListView.builder(
                                itemCount: maxLevel,
                                itemBuilder: (context, index) {
                                  final sublevel = index + 1;
                                  final isUnlocked = sublevel <= unlocked;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 15),
                                    child: GestureDetector(
                                      onTap: isUnlocked
                                          ? () {
                                              if (gameType == "surah") {
                                                // ถ้าเป็นนครแห่งอายะห์ → ไป SurahScreen เลย
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => const SurahScreen(),
                                                  ),
                                                );
                                              } else {
                                                // ถ้าเป็น alphabet หรือ vowel → ไป MinigameScreen
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => MinigameScreen(
                                                      gameType: gameType,
                                                      startLevel: sublevel,
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          : null,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: isUnlocked 
                                            ? const LinearGradient(
                                                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : LinearGradient(
                                                colors: [Colors.grey.shade300, Colors.grey.shade400],
                                              ),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isUnlocked 
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.grey.withOpacity(0.2),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Background Pattern (optional decorative element)
                                            Positioned(
                                              right: -20,
                                              top: -20,
                                              child: Container(
                                                width: 100,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            
                                            // Main Content
                                            Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Row(
                                                children: [
                                                  // Leading Circle with Number/Icon
                                                  Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(15),
                                                      border: Border.all(
                                                        color: Colors.white.withOpacity(0.3),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: isUnlocked 
                                                        ? (sublevel < unlocked
                                                            ? const Icon(
                                                                Icons.check_circle,
                                                                color: Colors.white,
                                                                size: 28,
                                                              )
                                                            : Text(
                                                                "$sublevel",
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 24,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ))
                                                        : const Icon(
                                                            Icons.lock,
                                                            color: Colors.white70,
                                                            size: 24,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                  
                                                  // Title and Info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // Level Description
                                                        Text(
                                                          _getLevelDescription(sublevel),
                                                          style: TextStyle(
                                                            color: isUnlocked 
                                                              ? Colors.white70 
                                                              : Colors.white60,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        // Level Name
                                                        Text(
                                                          _getLevelName(sublevel),
                                                          style: TextStyle(
                                                            color: isUnlocked 
                                                              ? Colors.white 
                                                              : Colors.white70,
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        // Status Badge
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Text(
                                                            isUnlocked 
                                                              ? "เล่นได้"
                                                              : "ล็อค",
                                                            style: TextStyle(
                                                              color: isUnlocked 
                                                                ? Colors.white 
                                                                : Colors.white70,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  
                                                  // Trailing Arrow/Status
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Icon(
                                                      isUnlocked 
                                                        ? Icons.arrow_forward_ios 
                                                        : Icons.lock_outline,
                                                      color: isUnlocked 
                                                        ? Colors.white 
                                                        : Colors.white70,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}