import 'package:flutter/material.dart';
import 'minigame_screen.dart';

class SublevelScreen extends StatelessWidget {
  final String gameType;
  final int maxLevel;

  const SublevelScreen({super.key, required this.gameType, required this.maxLevel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เลือกด่านย่อย")),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: maxLevel,
        itemBuilder: (context, index) {
          final sublevel = index + 1;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListTile(
              title: Text("ด่านย่อย $sublevel"),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MinigameScreen(
                      gameType: gameType,
                      startLevel: sublevel,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
