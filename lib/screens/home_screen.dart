import 'package:app_ai_quran/screens/profile_screen.dart';
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
      {"title": "หมู่บ้านอักษร", "type": "alphabet", "icon": Icons.text_fields},
      {"title": "โอเอซิสแห่งสระ", "type": "vowel", "icon": Icons.music_note},
      {"title": "นครแห่งอายะห์", "type": "surah", "icon": Icons.book},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.green)),
            ),
            const Text("Lv. 3 • 120 XP", style: TextStyle(fontSize: 18)),
            const Icon(Icons.star, color: Colors.yellow),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        itemCount: stages.length,
        itemBuilder: (context, index) {
          final stage = stages[index];
          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(55),
                onTap: () {
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
                },
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.green.shade300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(stage["icon"] as IconData,
                          size: 40, color: Colors.white),
                      const SizedBox(height: 5),
                      Text(stage["title"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (index < stages.length - 1)
                Container(
                  width: 4,
                  height: 40,
                  color: const Color.fromARGB(255, 12, 143, 16),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
            ],
          );
        },
      ),
    );
  }
}
