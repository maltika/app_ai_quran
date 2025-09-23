import 'package:app_ai_quran/screens/profile_screen.dart';
import 'package:app_ai_quran/screens/stage_selection_screen.dart';
import 'package:app_ai_quran/screens/sublevel.dart';
import 'package:flutter/material.dart';
import 'package:app_ai_quran/screens/minigame_screen.dart';
import 'package:app_ai_quran/screens/surah_detail_screen.dart';
import 'package:app_ai_quran/screens/surah_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stages = [
      {"title": "หมู่บ้านอักษร", "type": "alphabet", "icon": Icons.text_fields, "color": const Color(0xFF4CAF50)},
      {"title": "โอเอซิสแห่งสระ", "type": "vowel", "icon": Icons.music_note, "color": const Color(0xFF2196F3)},
      {"title": "นครแห่งอายะห์", "type": "surah", "icon": Icons.book, "color": const Color(0xFFFF9800)},
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
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person, 
                          color: Color(0xFF4CAF50),
                          size: 28,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: const Icon(
                          Icons.logout,
                          color: Color(0xFFE57373),
                          size: 28,
                        ),
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
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'เลือกเส้นทางการเรียนรู้ของคุณ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Stages List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  itemCount: stages.length,
                  itemBuilder: (context, index) {
                    final stage = stages[index];
                    final isLast = index == stages.length - 1;
                    
                    return Column(
                      children: [
                        // Stage Card
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(25),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(25),
                              onTap: () {
                                if (stage["type"] == "surah") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SurahScreen(),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SublevelScreen(
                                        gameType: stage["type"] as String,
                                        maxLevel: stage["type"] == "alphabet"
                                            ? 3
                                            : (stage["type"] == "vowel" ? 5 : 1),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      (stage["color"] as Color).withOpacity(0.8),
                                      (stage["color"] as Color).withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    // Icon Container
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        stage["icon"] as IconData,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 20),
                                    
                                    // Text Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stage["title"] as String,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _getStageDescription(stage["type"] as String),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Arrow Icon
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
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
                        
                        // Connecting Line
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
                                  (stage["color"] as Color).withOpacity(0.3),
                                  (stages[index + 1]["color"] as Color).withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
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
      case "alphabet":
        return "เรียนรู้ตัวอักษรอาหรับพื้นฐาน";
      case "vowel":
        return "เรียนรู้สระพื้นฐาน";
      case "surah":
        return "ฟังและฝึกอ่านกุรอาน";
      default:
        return "เริ่มต้นการเรียนรู้";
    }
  }
}