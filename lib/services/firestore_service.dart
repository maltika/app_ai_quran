import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> savePracticeResult(String surah, String result) async {
    if (uid == null) return;

    await _db.collection("users").doc(uid).collection("practice_logs").add({
      "surah": surah,
      "result": result,
      "xp": result == "✅ ดีเยี่ยม" ? 20 : 10,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPracticeLogs() {
    return _db
        .collection("users")
        .doc(uid)
        .collection("practice_logs")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
