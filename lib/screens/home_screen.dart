import 'package:app_ai_quran/screens/profile_screen.dart';
import 'package:app_ai_quran/screens/sublevel.dart';
import 'package:app_ai_quran/screens/surah_screen.dart';
import 'package:app_ai_quran/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ✅ เช็คว่าด่านใหญ่นี้ปลดล็อคแล้วหรือยัง
  bool _isStageUnlocked(String type, Map<String, dynamic> sublevels) {
    switch (type) {
      case "letter":
        return true; // ด่านแรกเปิดเสมอ
      case "vowel":
        final letterUnlocked = (sublevels["letter"] as int?) ?? 1;
        return letterUnlocked > 3; // ผ่านครบ 3 ด่านย่อยของ letter
      case "surah":
        final vowelUnlocked = (sublevels["vowel"] as int?) ?? 1;
        return vowelUnlocked > 5; // ผ่านครบ 5 ด่านย่อยของ vowel
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = [
      {"title": "หมู่บ้านอักษร", "type": "letter", "icon": Icons.text_fields, "color": const Color(0xFF4CAF50), "maxLevel": 3},
      {"title": "โอเอซิสแห่งสระ", "type": "vowel", "icon": Icons.music_note, "color": const Color(0xFF2196F3), "maxLevel": 5},
      {"title": "นครแห่งอายะห์", "type": "surah", "icon": Icons.book, "color": const Color(0xFFFF9800), "maxLevel": 1},
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF81C784),
              Color(0xFFA5D6A7),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF4CAF50), size: 28),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, "/login"),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.logout, color: Color(0xFFE57373), size: 28),
                      ),
                    ),
                  ],
                ),
              ),

              // Welcome Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Text(
                      'ยินดีต้อนรับ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(offset: const Offset(0, 2), blurRadius: 4, color: Colors.black.withOpacity(0.3))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'เลือกเส้นทางการเรียนรู้ของคุณ',
                      style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ✅ StreamBuilder ดึงข้อมูล Firestore
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirestoreService().getUserStream(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final sublevels = data["unlockedSublevels"] as Map<String, dynamic>? ?? {};

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      itemCount: stages.length,
                      itemBuilder: (context, index) {
                        final stage = stages[index];
                        final isLast = index == stages.length - 1;
                        final type = stage["type"] as String;
                        final color = stage["color"] as Color;

                        // ✅ เช็คว่าปลดล็อคหรือยัง
                        final isUnlocked = _isStageUnlocked(type, sublevels);

                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              child: Material(
                                elevation: isUnlocked ? 8 : 2,
                                borderRadius: BorderRadius.circular(25),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: isUnlocked
                                      ? () {
                                          if (type == "surah") {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SurahScreen()));
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SublevelScreen(
                                                  gameType: type,
                                                  maxLevel: stage["maxLevel"] as int,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      : () {
                                          // ✅ แจ้งเตือนตอนกดด่านที่ยังล็อค
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                type == "vowel"
                                                    ? "ผ่านหมู่บ้านอักษรให้ครบก่อนนะ!"
                                                    : "ผ่านโอเอซิสแห่งสระให้ครบก่อนนะ!",
                                              ),
                                              backgroundColor: Colors.orange,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isUnlocked
                                            ? [color.withOpacity(0.8), color.withOpacity(0.6)]
                                            : [Colors.grey.shade400, Colors.grey.shade300], // ✅ สีเทาถ้าล็อค
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Icon(
                                            isUnlocked ? stage["icon"] as IconData : Icons.lock, // ✅ icon กุญแจถ้าล็อค
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stage["title"] as String,
                                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                isUnlocked
                                                    ? _getStageDescription(type)
                                                    : _getLockDescription(type), // ✅ บอกเงื่อนไขปลดล็อค
                                                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          child: Icon(
                                            isUnlocked ? Icons.arrow_forward_ios : Icons.lock_outline,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 6,
                                height: 50,
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      color.withOpacity(0.3),
                                      (stages[index + 1]["color"] as Color).withOpacity(0.3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getStageDescription(String type) {
    switch (type) {
      case "letter": return "เรียนรู้ตัวอักษรอาหรับพื้นฐาน";
      case "vowel": return "เรียนรู้สระพื้นฐาน";
      case "surah": return "ฟังและฝึกอ่านกุรอาน";
      default: return "เริ่มต้นการเรียนรู้";
    }
  }

  // ✅ ข้อความบอกเงื่อนไขการปลดล็อค
  String _getLockDescription(String type) {
    switch (type) {
      case "vowel": return "🔒 ผ่านหมู่บ้านอักษรก่อน";
      case "surah": return "🔒 ผ่านโอเอซิสแห่งสระก่อน";
      default: return "🔒 ยังล็อคอยู่";
    }
  }
}