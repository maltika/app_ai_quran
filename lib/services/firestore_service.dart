import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> ensureUserExists() async {
  if (uid == null) return;
  final userRef = _db.collection("users").doc(uid);
  final doc = await userRef.get();
  if (!doc.exists) {
    await userRef.set({
      "totalXp": 0,
      "unlockedSublevels": {
        "letter": 1,
        // "vowel": 1,
      },
    });
  }
}

  Future<void> savePracticeResult({
  required String gameType,
  required int sublevel,
  required String itemPlayed,
  required bool isCorrect,
  required int xpGained,
  double? aiScore,
  String? aiFeedback,
}) async {
  if (uid == null) return;

  await ensureUserExists();
  final userRef = _db.collection("users").doc(uid);

  await userRef.collection("practice_logs").add({
    "gameType": gameType,
    "sublevel": sublevel,
    "itemPlayed": itemPlayed,
    "isCorrect": isCorrect,
    "xpGained": xpGained,
    "timestamp": FieldValue.serverTimestamp(),
    if (aiScore != null) "aiScore": aiScore,
    if (aiFeedback != null) "aiFeedback": aiFeedback,
  });

  await userRef.update({
    "totalXp": FieldValue.increment(xpGained),
  });

  // unlock ด่านถัดไป เฉพาะตอนผ่านด่านนั้นจริงๆ
  if (isCorrect) {
    final doc = await userRef.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sublevels = data["unlockedSublevels"] as Map<String, dynamic>? ?? {};
    final currentUnlocked = (sublevels[gameType] as int?) ?? 1;

    // unlock เฉพาะถ้าด่านที่เพิ่งเล่น >= ด่านที่ unlock ล่าสุด
    if (sublevel >= currentUnlocked) {
      await userRef.update({
        "unlockedSublevels.$gameType": sublevel + 1,
      });
    }
  }
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
