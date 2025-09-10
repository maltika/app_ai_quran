import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ สร้างเอกสาร user ใน Firestore ด้วย
      await _db.collection("users").doc(cred.user!.uid).set({
        "email": email,
        "totalXp": 0,
        "unlockedSublevel": 1,
        "createdAt": FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
