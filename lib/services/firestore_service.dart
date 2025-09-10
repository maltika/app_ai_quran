import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> savePracticeResult(String type, String result,
      {int sublevel = 1}) async {
    if (uid == null) return;

    final xp = result == "✅ ดีเยี่ยม" ? 10 : 0;
    final userRef = _db.collection("users").doc(uid);

    // 🟢 ถ้า user ไม่มี document → สร้างให้
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        "totalXp": 0,
        "unlockedSublevel": 1,
      });
    }

    // 🟢 บันทึก log
    await userRef.collection("practice_logs").add({
      "type": type,
      "result": result,
      "xpGained": xp,
      "sublevel": sublevel,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // 🟢 อัปเดตค่า XP + ปลดล็อก sublevel
    await userRef.set({
      "totalXp": FieldValue.increment(xp),
      "unlockedSublevel": FieldValue.increment(result == "✅ ดีเยี่ยม" ? 1 : 0),
    }, SetOptions(merge: true));
  }

  Future<void> addXpOnce(int gainedXp, {int sublevel = 1}) async {
    if (uid == null || gainedXp <= 0) return;

    final userRef = _db.collection("users").doc(uid);

    // ถ้า user ยังไม่มี doc → สร้างใหม่
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        "totalXp": 0,
        "unlockedSublevel": 1,
      });
    }

    // Log รอบนี้ (ครั้งเดียว)
    await userRef.collection("practice_logs").add({
      "type": "minigame",
      "result": "จบรอบ",
      "xpGained": gainedXp,
      "sublevel": sublevel,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // อัปเดต XP รวม
    await userRef.set({
      "totalXp": FieldValue.increment(gainedXp),
      "unlockedSublevel": FieldValue.increment(1), // ปลดล็อกไปอีกด่านถ้าอยาก
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getUserStream() {
    return _db.collection("users").doc(uid).snapshots();
  }

  Stream<QuerySnapshot> getHistory() {
    return _db
        .collection("users")
        .doc(uid)
        .collection("practice_logs")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
