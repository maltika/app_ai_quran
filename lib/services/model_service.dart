import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  late Interpreter _interpreter;

  /// โหลดโมเดล
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'model/model.tflite',
      options: InterpreterOptions()..threads = 4,
    );

    print("Model loaded");
    print("Input shape: ${_interpreter.getInputTensor(0).shape}");
    print("Output shape: ${_interpreter.getOutputTensor(0).shape}");
  }

  /// รันโมเดล
  List<double> runModel(List<double> features) {
    var input = [features];

    var output = List.generate(
      1,
      (_) => List.filled(2, 0.0),
    );

    _interpreter.run(input, output);

    return output[0];
  }

  /// ปิด interpreter
  void close() {
    _interpreter.close();
  }
}