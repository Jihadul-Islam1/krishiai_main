import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'scan_prediction.dart';

/// On-device rice leaf disease classifier (MobileNetV3, trained in
/// `ml/rice_disease_training.ipynb`).
///
/// Contract with the training notebook — keep these in sync:
/// * input `[1, size, size, 3]` float32 RGB in the **0–255** range
///   (the model rescales internally, so do NOT divide by 255),
/// * bilinear resize without keeping aspect ratio, like `tf.image.resize`,
/// * softmax output in the order of `rice_labels.txt`.
class RiceDiseaseClassifier {
  RiceDiseaseClassifier._(
    this._interpreter,
    this._isolate,
    this.labels,
    this._inputSize,
  );

  static const _modelAsset = 'assets/models/rice.tflite';
  static const _labelsAsset = 'assets/models/rice_labels.txt';

  /// From the notebook's threshold table (label smoothing keeps scores low):
  /// ≥ 0.5 covered 85% of test images at 96% accuracy.
  static const confidentThreshold = 0.5;

  /// Below this the app says "not recognised" instead of guessing.
  static const minThreshold = 0.4;

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  final List<String> labels;
  final int _inputSize;

  static Future<RiceDiseaseClassifier> load() async {
    final interpreter = await Interpreter.fromAsset(
      _modelAsset,
      options: InterpreterOptions()..threads = 4,
    );
    final labels = (await rootBundle.loadString(
      _labelsAsset,
    )).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (outputShape.last != labels.length) {
      throw StateError(
        'rice model has ${outputShape.last} outputs but '
        '${labels.length} labels — model and rice_labels.txt are out of sync',
      );
    }

    final isolate = await IsolateInterpreter.create(
      address: interpreter.address,
    );
    return RiceDiseaseClassifier._(interpreter, isolate, labels, inputShape[1]);
  }

  Future<ScanPrediction> classify(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    // Decode + resize is the slow part; keep it off the UI thread.
    final input = await compute(
      _preprocess,
      _PreprocessArgs(bytes, _inputSize),
    );

    final output = [List<double>.filled(labels.length, 0)];
    await _isolate.run(input, output);

    final ranked = [
      for (var i = 0; i < labels.length; i++)
        LabelScore(labels[i], output[0][i]),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return ScanPrediction(ranked);
  }

  Future<void> dispose() async {
    await _isolate.close();
    _interpreter.close();
  }
}

class _PreprocessArgs {
  const _PreprocessArgs(this.bytes, this.size);

  final Uint8List bytes;
  final int size;
}

/// Returns the raw float32 bytes of a `[1, size, size, 3]` tensor.
Uint8List _preprocess(_PreprocessArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    throw const FormatException('ছবিটি পড়া যায়নি');
  }
  // Camera photos carry their rotation in EXIF; apply it before resizing.
  final upright = img.bakeOrientation(decoded);
  final resized = img.copyResize(
    upright,
    width: args.size,
    height: args.size,
    interpolation: img.Interpolation.linear,
  );

  final pixels = Float32List(args.size * args.size * 3);
  var i = 0;
  for (var y = 0; y < args.size; y++) {
    for (var x = 0; x < args.size; x++) {
      // Normalized → 0..255 so 16-bit / palette PNGs scale like 8-bit JPEGs.
      final p = resized.getPixel(x, y);
      pixels[i++] = p.rNormalized * 255;
      pixels[i++] = p.gNormalized * 255;
      pixels[i++] = p.bNormalized * 255;
    }
  }
  return pixels.buffer.asUint8List();
}
