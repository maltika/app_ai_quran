import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'minigame_screen.dart';
import 'surah_screen.dart'; // ต้อง import ด้วยนะ

class SublevelScreen extends StatelessWidget {
  final String gameType;
  final int maxLevel;

  const SublevelScreen({super.key, required this.gameType, required this.maxLevel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เลือกด่านย่อย")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService().getUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final unlocked = data["unlockedSublevel"] ?? 1;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: maxLevel,
            itemBuilder: (context, index) {
              final sublevel = index + 1;
              final isUnlocked = sublevel <= unlocked;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  title: Text("ด่านย่อย $sublevel"),
                  trailing: isUnlocked ? const Icon(Icons.arrow_forward) : const Icon(Icons.lock),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
