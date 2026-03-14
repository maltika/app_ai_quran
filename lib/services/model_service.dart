import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';

class ModelService {
  // Singleton
  static final ModelService instance = ModelService._internal();
  ModelService._internal();

  OrtSession? _session;

  // ─── config ตรงกับตอน train ───────────────────────────────────────────────
  static const int sampleRate = 16000;
  static const int nMfcc = 40;
  static const int fftSize = 512;
  static const int hopLength = 160;
  static const int targetFrames = 300;
  static const int numClasses = 3; // ✅ fixed: model has 3 classes

  // ─── โหลดโมเดล (Lazy Load) ────────────────────────────────────────────────
  Future<void> init() async {
    if (_session != null) return;
    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      final rawAssetFile =
          await rootBundle.load('assets/models/quran_model_v9.onnx');
      final bytes = rawAssetFile.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      print("🚀 ONNX Model loaded successfully");
    } catch (e) {
      print("❌ Model Load Error: $e");
    }
  }

  // ─── ฟังก์ชันหลัก ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> predict(String wavFilePath) async {
    await init();

    // 1. อ่าน WAV → PCM float32
    final Float32List pcm = await _readWav(wavFilePath);

    // 2. ✅ ตรวจสอบว่าเงียบเกินไปไหม
    final double rms = _computeRMS(pcm);
    print("🔍 RMS: $rms");
    // ในฟังก์ชัน predict
    if (rms < 0.025) {
      // ปรับจาก 0.01 เป็น 0.025
      return {
        'surahIndex': -1,
        'confidence': 0.0,
        'level': 'try',
        'isSilence': true,
      };
    }

    // 3. คำนวณ MFCC [300, 40]
    final List<List<double>> mfcc = _computeMfcc(pcm);

    // 4. Flatten → Float32List [1, 300, 40]
    final Float32List flat = _flattenMfcc(mfcc);

    // 5. สร้าง input tensor shape [1, 300, 40]
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      flat,
      [1, targetFrames, nMfcc],
    );

    // 6. รัน inference
    final inputs = {'mfcc': inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = _session!.run(runOptions, inputs);

    // 7. ✅ ดึง output logits - handle List<List<double>>
    final outputTensor = outputs.first as OrtValueTensor;
    final rawOutput = outputTensor.value;
    print("🔍 Output type: ${rawOutput.runtimeType}");
    print("🔍 Output value: $rawOutput");

    List<double> logits = [];
    if (rawOutput is List<List<double>>) {
      logits = rawOutput[0]; // batch แรก
    } else if (rawOutput is List<double>) {
      logits = rawOutput;
    } else if (rawOutput is List<List<List<double>>>) {
      logits = rawOutput[0][0];
    } else {
      print("❌ Unknown output type: ${rawOutput.runtimeType}");
    }

    // 8. cleanup
    inputTensor.release();
    outputTensor.release();
    runOptions.release();

    // 9. Softmax
    final List<double> probs = _softmax(logits);
    final int idx = _argmax(probs);
    final double confidence = probs[idx];

    // 10. ✅ Entropy check - ถ้า model ไม่มั่นใจจริงๆ
    final double entropy = _entropy(probs);
    final double maxEntropy = math.log(numClasses) / math.ln2;
    final double normalizedEntropy = entropy / maxEntropy; // 0.0 - 1.0
    print("🔍 confidence: $confidence, entropy: $normalizedEntropy");

    // ถ้า entropy สูงมาก = เสียงไม่ชัด/ไม่ตรงกับที่เรียนมา
    if (normalizedEntropy > 0.7) {
      return {
        'surahIndex': -1,
        'confidence': confidence,
        'level': 'unclear', // 🎤 ไม่ชัดเจน
      };
    }

    // ถ้า confidence ต่ำเกินไป
    if (confidence < 0.70) {
      return {
        'surahIndex': -1,
        'confidence': confidence,
        'level': 'unclear',
      };
    }

    return {
      'surahIndex': idx,
      'confidence': confidence,
      'level': _getLevel(confidence),
    };
  }

  // ─── RMS (ตรวจระดับเสียง) ─────────────────────────────────────────────────
  double _computeRMS(Float32List pcm) {
    if (pcm.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in pcm) sum += s * s;
    return math.sqrt(sum / pcm.length);
  }

  // ─── Entropy ──────────────────────────────────────────────────────────────
  double _entropy(List<double> probs) {
    double h = 0.0;
    for (final p in probs) {
      if (p > 1e-9) h -= p * math.log(p) / math.ln2;
    }
    return h;
  }

  // ─── อ่าน WAV → Float32List ───────────────────────────────────────────────
  Future<Float32List> _readWav(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();

    const int headerSize = 44;
    if (bytes.length <= headerSize) return Float32List(0);

    // อ่าน sample rate จาก WAV header (offset 24)
    final ByteData header = ByteData.view(bytes.buffer, 0, headerSize);
    final int fileSampleRate = header.getInt32(24, Endian.little);

    // Int16 PCM → Float32 normalize [-1, 1]
    final ByteData body = ByteData.view(bytes.buffer, headerSize);
    final int sampleCount = body.lengthInBytes ~/ 2;
    final Float32List pcm = Float32List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      pcm[i] = body.getInt16(i * 2, Endian.little) / 32768.0;
    }

    // Resample ถ้า sample rate ไม่ตรง
    if (fileSampleRate != sampleRate) {
      return _resample(pcm, fileSampleRate, sampleRate);
    }
    return pcm;
  }

  // ─── Resample ─────────────────────────────────────────────────────────────
  Float32List _resample(Float32List pcm, int fromRate, int toRate) {
    final int newLen = (pcm.length * toRate / fromRate).round();
    final Float32List out = Float32List(newLen);
    for (int i = 0; i < newLen; i++) {
      final double pos = i * pcm.length / newLen;
      final int idx = pos.toInt().clamp(0, pcm.length - 2);
      final double frac = pos - idx;
      out[i] = pcm[idx] * (1 - frac) + pcm[idx + 1] * frac;
    }
    return out;
  }

  // ─── คำนวณ MFCC ───────────────────────────────────────────────────────────
  List<List<double>> _computeMfcc(Float32List pcm) {
    final List<List<double>> frames = [];
    final List<List<double>> melFilters = _buildMelFilterbank();

    for (int start = 0;
        start + fftSize <= pcm.length && frames.length < targetFrames;
        start += hopLength) {
      // Hann window
      final Float32List frame = Float32List(fftSize);
      for (int i = 0; i < fftSize; i++) {
        frame[i] = pcm[start + i] *
            (0.5 * (1 - math.cos(2 * math.pi * i / (fftSize - 1))));
      }

      // Power spectrum
      final List<double> power = _powerSpectrum(frame);

      // Mel filterbank + log
      final List<double> mel = List.filled(nMfcc, 0.0);
      for (int m = 0; m < nMfcc; m++) {
        for (int k = 0; k < power.length; k++) {
          mel[m] += melFilters[m][k] * power[k];
        }
        mel[m] = math.log(mel[m] + 1e-9);
      }

      // DCT → MFCC coefficients
      frames.add(_dct(mel));
    }

    // Pad ให้ครบ 300 frames ถ้าเสียงสั้น
    while (frames.length < targetFrames) {
      frames.add(List.filled(nMfcc, 0.0));
    }

    return frames;
  }

  // ─── Power Spectrum ───────────────────────────────────────────────────────
  List<double> _powerSpectrum(Float32List frame) {
    final int n = frame.length;
    final int halfN = n ~/ 2 + 1;
    final List<double> out = List.filled(halfN, 0.0);
    for (int k = 0; k < halfN; k++) {
      double re = 0, im = 0;
      for (int t = 0; t < n; t++) {
        final double angle = 2 * math.pi * k * t / n;
        re += frame[t] * math.cos(angle);
        im -= frame[t] * math.sin(angle);
      }
      out[k] = (re * re + im * im) / n;
    }
    return out;
  }

  // ─── Mel Filterbank ───────────────────────────────────────────────────────
  List<List<double>> _buildMelFilterbank() {
    double hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;
    double melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

    final int bins = fftSize ~/ 2 + 1;
    final double melMin = hzToMel(0);
    final double melMax = hzToMel(sampleRate / 2.0);

    final List<int> hzBins = List.generate(nMfcc + 2, (i) {
      final double mel = melMin + i * (melMax - melMin) / (nMfcc + 1);
      return ((melToHz(mel) / (sampleRate / 2)) * (bins - 1))
          .round()
          .clamp(0, bins - 1);
    });

    return List.generate(nMfcc, (m) {
      final List<double> filt = List.filled(bins, 0.0);
      for (int k = hzBins[m]; k < hzBins[m + 1]; k++) {
        filt[k] = (k - hzBins[m]) / (hzBins[m + 1] - hzBins[m] + 1e-9);
      }
      for (int k = hzBins[m + 1]; k <= hzBins[m + 2] && k < bins; k++) {
        filt[k] = (hzBins[m + 2] - k) / (hzBins[m + 2] - hzBins[m + 1] + 1e-9);
      }
      return filt;
    });
  }

  // ─── DCT Type-II ──────────────────────────────────────────────────────────
  List<double> _dct(List<double> input) {
    final int n = input.length;
    final List<double> out = List.filled(nMfcc, 0.0);
    for (int k = 0; k < nMfcc; k++) {
      double sum = 0;
      for (int i = 0; i < n; i++) {
        sum += input[i] * math.cos(math.pi * k * (i + 0.5) / n);
      }
      out[k] = sum;
    }
    return out;
  }

  // ─── Flatten [300, 40] → Float32List [12000] ─────────────────────────────
  Float32List _flattenMfcc(List<List<double>> mfcc) {
    final Float32List flat = Float32List(targetFrames * nMfcc);
    for (int t = 0; t < targetFrames; t++) {
      for (int f = 0; f < nMfcc; f++) {
        flat[t * nMfcc + f] = mfcc[t][f];
      }
    }
    return flat;
  }

  // ─── Softmax ──────────────────────────────────────────────────────────────
  List<double> _softmax(List<double> logits, {double temperature = 2.0}) {
    // หาร logits ด้วย temperature → ทำให้ confidence กระจายมากขึ้น
    final scaled = logits.map((x) => x / temperature).toList();
    final double maxVal = scaled.reduce(math.max);
    final List<double> exp = scaled.map((x) => math.exp(x - maxVal)).toList();
    final double sum = exp.reduce((a, b) => a + b);
    return exp.map((x) => x / sum).toList();
  }

  // ─── Argmax ───────────────────────────────────────────────────────────────
  int _argmax(List<double> probs) {
    int best = 0;
    double bestV = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestV) {
        bestV = probs[i];
        best = i;
      }
    }
    return best;
  }

  // ─── ระดับความมั่นใจ ──────────────────────────────────────────────────────
  String _getLevel(double confidence) {
    if (confidence >= 0.99) return 'excellent'; // 🌟 เก่งมาก
    if (confidence >= 0.65) return 'good'; // 👍 พอใช้
    return 'try'; // 💪 พยายามเข้า
  }

  // ─── ปิด session ──────────────────────────────────────────────────────────
  void dispose() {
    _session?.release();
    _session = null;
  }
}
