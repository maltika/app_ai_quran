import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  /// สำหรับการบันทึกผลปกติ
  Future<void> savePracticeResult(String type, String result,
      {int sublevel = 1}) async {
    if (uid == null) return;

    final xp = result == "✅ ดีเยี่ยม" ? 10 : 0;
    final userRef = _db.collection("users").doc(uid);

    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        "totalXp": 0,
        "unlockedSublevel": 1,
      });
    }

    await userRef.collection("practice_logs").add({
      "type": type,
      "result": result,
      "xpGained": xp,
      "sublevel": sublevel,
      "timestamp": FieldValue.serverTimestamp(),
    });

    await userRef.set({
      "totalXp": FieldValue.increment(xp),
      "unlockedSublevel": FieldValue.increment(result == "✅ ดีเยี่ยม" ? 1 : 0),
    }, SetOptions(merge: true));
  }

  
  /// สำหรับบันทึก XP แบบรวมทั้งด่าน
  Future<void> addXpOnce(
    int gainedXp, {
    int sublevel = 1,
    String resultText = "✅ ดีเยี่ยม",
    String levelName = "Unknown Level", // ส่งชื่อด่านใหญ่เข้ามา
    String gameType = "", // เพิ่ม type เกม เช่น "alphabet" หรือ "vowel"
  }) async {
    if (uid == null || gainedXp <= 0) return;

    final userRef = _db.collection("users").doc(uid);

    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        "totalXp": 0,
        "unlockedSublevel": 1,
      });
    }

    await userRef.collection("practice_logs").add({
      "levelName": levelName, // ด่านใหญ่
      "type": "$gameType level $sublevel", // <-- ✅ แก้ตรงนี้
      "result": resultText, // ✅ ดีเยี่ยม หรือ 💪 พยายาม
      "xpGained": gainedXp,
      "sublevel": sublevel,
      "timestamp": FieldValue.serverTimestamp(),
    });

    await userRef.set({
      "totalXp": FieldValue.increment(gainedXp),
      "unlockedSublevel": FieldValue.increment(1),
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
