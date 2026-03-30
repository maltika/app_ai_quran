import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';

class ModelService {
  static final ModelService instance = ModelService._internal();
  ModelService._internal();

  OrtSession? _session;

  static const int sampleRate = 16000;
  static const int nMfcc = 40;
  static const int fftSize = 400; 
  static const int hopLength = 160;
  static const int targetFrames = 300;
  static const int numClasses = 3;

  static const Map<int, String> labelMap = {
    0: "1 พยายามเข้า",
    1: "2 พอใช้",
    2: "3 เก่งมาก",
  };

  Future<void> init() async {
    if (_session != null) return;
    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      final rawAssetFile = await rootBundle.load('assets/models/quran_model_v9.onnx');
      final bytes = rawAssetFile.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      print("🚀 ONNX Model Loaded (Ready for 99% accuracy)");
    } catch (e) {
      print("❌ Load Error: $e");
    }
  }

  // ─── ฟังก์ชันช่วยจัดการ Noise และความดัง ───────────────────────────────────────
  
  void _applyNoiseGate(Float32List pcm) {
    // ตัดเสียงซ่าเบาๆ ทิ้ง (Noise Gate)
    const double threshold = 0.015; 
    for (int i = 0; i < pcm.length; i++) {
      if (pcm[i].abs() < threshold) pcm[i] = 0.0;
    }
  }

  void _normalize(Float32List pcm) {
    // เร่งเสียงให้ Peak อยู่ที่ 1.0 เสมอ (Normalization)
    if (pcm.isEmpty) return;
    double maxVal = 0.0;
    for (var s in pcm) {
      if (s.abs() > maxVal) maxVal = s.abs();
    }
    if (maxVal > 0.01) { // ป้องกันการเร่งเสียงเงียบจน Noise ดัง
      for (int i = 0; i < pcm.length; i++) pcm[i] /= maxVal;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> predict(String wavFilePath) async {
    await init();
    final Float32List pcm = await _readWav(wavFilePath);
    
    if (_computeRMS(pcm) < 0.02) return {'level': 'เงียบเกินไป', 'confidence': 0.0};

    // ✅ เคลียร์ Noise และเร่งเสียงก่อนส่งประเมิน
    _applyNoiseGate(pcm);
    _normalize(pcm);

    final List<List<double>> mfcc = _computeLibrosaLikeMfcc(pcm);
    final Float32List flat = _flattenMfcc(mfcc);

    final inputTensor = OrtValueTensor.createTensorWithDataList(flat, [1, targetFrames, nMfcc]);
    final inputs = {'mfcc': inputTensor};
    
    final outputs = _session!.run(OrtRunOptions(), inputs);
    final firstOutput = outputs.first;
    
    if (firstOutput == null) {
      return {'level': 'Error: No Output', 'confidence': 0.0};
    }

    final List<double> logits = (firstOutput.value as List<List<double>>)[0];
    
    firstOutput.release();
    inputTensor.release();

    final List<double> probs = _softmax(logits, temperature: 1.0);
    final int idx = _argmax(probs);
    final double confidence = probs[idx];

    print("🎯 Result: ${labelMap[idx]} (${(confidence * 100).toStringAsFixed(1)}%)");

    return {
      'surahIndex': idx,
      'confidence': confidence,
      'level': labelMap[idx] ?? 'Unknown',
    };
  }

  List<List<double>> _computeLibrosaLikeMfcc(Float32List pcm) {
    final List<List<double>> frames = [];
    final List<List<double>> melFilters = _buildMelFilterbank();
    final List<double> window = List.generate(fftSize, (i) => 0.5 * (1 - math.cos(2 * math.pi * i / (fftSize - 1))));

    for (int start = 0; start + fftSize <= pcm.length && frames.length < targetFrames; start += hopLength) {
      final List<double> frame = List.generate(fftSize, (i) => pcm[start + i] * window[i]);
      final List<double> power = _powerSpectrum(frame);
      final List<double> melSpec = List.filled(nMfcc, 0.0);
      for (int m = 0; m < nMfcc; m++) {
        for (int k = 0; k < power.length; k++) {
          melSpec[m] += melFilters[m][k] * power[k];
        }
        melSpec[m] = 10.0 * (math.log(math.max(melSpec[m], 1e-10)) / math.ln10);
      }
      frames.add(_dctOrtho(melSpec));
    }
    while (frames.length < targetFrames) frames.add(List.filled(nMfcc, 0.0));
    return frames;
  }

  List<double> _powerSpectrum(List<double> frame) {
    final int n = frame.length;
    final int halfN = n ~/ 2 + 1;
    final List<double> out = List.filled(halfN, 0.0);
    for (int k = 0; k < halfN; k++) {
      double re = 0, im = 0;
      for (int t = 0; t < n; t++) {
        double angle = 2 * math.pi * k * t / n;
        re += frame[t] * math.cos(angle);
        im -= frame[t] * math.sin(angle);
      }
      out[k] = (re * re + im * im); 
    }
    return out;
  }

  List<double> _dctOrtho(List<double> mel) {
    final int n = mel.length;
    final List<double> res = List.filled(n, 0.0);
    for (int k = 0; k < n; k++) {
      double sum = 0;
      for (int i = 0; i < n; i++) {
        sum += mel[i] * math.cos(math.pi * k * (i + 0.5) / n);
      }
      double scale = (k == 0) ? math.sqrt(1.0 / n) : math.sqrt(2.0 / n);
      res[k] = sum * scale;
    }
    return res;
  }

  List<List<double>> _buildMelFilterbank() {
    double hzToMel(double hz) => 2595 * (math.log(1 + hz / 700) / math.ln10);
    double melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);
    final int bins = fftSize ~/ 2 + 1;
    final double minMel = hzToMel(0);
    final double maxMel = hzToMel(sampleRate / 2.0);
    final List<int> binIdx = List.generate(nMfcc + 2, (i) {
      double m = minMel + i * (maxMel - minMel) / (nMfcc + 1);
      return (melToHz(m) * fftSize / sampleRate).round();
    });
    return List.generate(nMfcc, (i) {
      final List<double> filter = List.filled(bins, 0.0);
      for (int j = binIdx[i]; j < binIdx[i+1]; j++) filter[j] = (j - binIdx[i]) / (binIdx[i+1] - binIdx[i]);
      for (int j = binIdx[i+1]; j < binIdx[i+2]; j++) filter[j] = (binIdx[i+2] - j) / (binIdx[i+2] - binIdx[i+1]);
      return filter;
    });
  }

  List<double> _softmax(List<double> x, {double temperature = 1.0}) {
    double max = x.reduce(math.max);
    List<double> exp = x.map((v) => math.exp((v - max) / temperature)).toList();
    double sum = exp.reduce((a, b) => a + b);
    return exp.map((v) => v / sum).toList();
  }
  
  int _argmax(List<double> list) => list.indexOf(list.reduce(math.max));
  double _computeRMS(Float32List p) => math.sqrt(p.isEmpty ? 0 : p.map((x)=>x*x).reduce((a,b)=>a+b)/p.length);
  Float32List _flattenMfcc(List<List<double>> m) => Float32List.fromList(m.expand((x)=>x).toList());

  Future<Float32List> _readWav(String p) async {
    final b = await File(p).readAsBytes();
    if (b.length < 44) return Float32List(0);
    final d = ByteData.view(b.buffer, 44);
    return Float32List.fromList(List.generate(d.lengthInBytes ~/ 2, (i) => d.getInt16(i * 2, Endian.little) / 32768.0));
  }
  
  void dispose() {
    _session?.release();
    _session = null;
  }
}