import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  int _calculateLevel(int xp) => (xp ~/ 100) + 1;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("โปรไฟล์")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getPracticeLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "ไม่มีข้อมูลการเล่น",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          int totalXp = 0, excellent = 0, tryCount = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalXp += int.tryParse((data["xp"] ?? 0).toString()) ?? 0;
            if ((data["result"] ?? "").contains("ดีเยี่ยม")) excellent++;
            else tryCount++;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(user?.email ?? "ไม่ทราบ", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: (totalXp % 100) / 100,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.green,
                  minHeight: 10,
                ),
                const SizedBox(height: 10),
                Text("Level ${_calculateLevel(totalXp)} • $totalXp XP"),
                const SizedBox(height: 20),
                Text("✅ ดีเยี่ยม: $excellent • ⚠️ พยายามเข้า: $tryCount"),
                const Divider(height: 40),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            (data["result"] ?? "").contains("ดีเยี่ยม")
                                ? Icons.check_circle
                                : Icons.warning,
                            color: (data["result"] ?? "").contains("ดีเยี่ยม")
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(data["surah"] ?? "-"),
                          subtitle: Text("ผล: ${data["result"] ?? "-"}"),
                          trailing: Text("+${data["xp"] ?? 0} XP"),
                        ),
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
