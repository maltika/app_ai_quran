import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TestRecordScreen extends StatefulWidget {
  const TestRecordScreen({super.key});

  @override
  State<TestRecordScreen> createState() => _TestRecordScreenState();
}

class _TestRecordScreenState extends State<TestRecordScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ ไม่มีสิทธิ์เข้าถึงไมค์")),
      );
      return;
    }

    // ใช้ documents directory ของแอพ (ไม่ติด Scoped Storage)
    final dir = await getApplicationDocumentsDirectory();
    final filePath = "${dir.path}/my_record.m4a";

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // ใช้ .m4a
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _filePath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _filePath = path; // path จริง ๆ ที่บันทึกได้
    });

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ บันทึกเสียงแล้ว: $path")),
      );
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ทดสอบอัดเสียง")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording)
              ElevatedButton(
                onPressed: _stopRecording,
                child: const Text("หยุดอัด"),
              )
            else
              ElevatedButton(
                onPressed: _startRecording,
                child: const Text("เริ่มอัดเสียง"),
              ),
            const SizedBox(height: 20),
            if (_filePath != null)
              Text("ไฟล์: $_filePath", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
