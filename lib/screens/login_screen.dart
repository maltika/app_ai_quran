import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../services/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void login() async {
    final success = await FirebaseAuthService().signIn(
      emailController.text,
      passwordController.text,
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, "/home");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Login failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 100, color: Color(0xFF58CC02)),
            const SizedBox(height: 20),
            const Text("Quran Recitation",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF58CC02))),
            const SizedBox(height: 30),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 15),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 25),
            ElevatedButton(onPressed: login, child: const Text("Login")),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
              },
              child: const Text("ยังไม่มีบัญชี? สมัครสมาชิก", style: TextStyle(color: Colors.green)),
            )
          ],
        ),
      ),
    );
  }
}
