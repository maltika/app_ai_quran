import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  int _calculateLevel(int xp) => (xp ~/ 100) + 1;
  int _xpForNextLevel(int xp) => 100 - (xp % 100);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("โปรไฟล์")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirestoreService().getUserStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final totalXp = data["totalXp"] ?? 0;
          final level = _calculateLevel(totalXp);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green,
                  child:
                      const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(user?.email ?? "ไม่ทราบ",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: (totalXp % 100) / 100, // 0.0 → 1.0
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.green,
                  minHeight: 10,
                ),
                SizedBox(height: 10),
                Text(
                    "Level $level • $totalXp XP • อีก ${_xpForNextLevel(totalXp)} XP ถึงเลเวลถัดไป"),

                const SizedBox(height: 10),
                Text("Level $level • $totalXp XP"),
                const Divider(height: 40),

                // 🟢 แสดง history
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService().getHistory(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Text("ยังไม่มีประวัติ");

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                (data["result"] ?? "").contains("ดีเยี่ยม")
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color:
                                    (data["result"] ?? "").contains("ดีเยี่ยม")
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                              title: Text(data["type"] ?? "-"),
                              subtitle: Text("ผล: ${data["result"] ?? "-"}"),
                              trailing: Text("+${data["xpGained"] ?? 0} XP"),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
