import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart'
    as img; // 'image' প্যাকেজটি ইমেজ প্রসেস করতে সাহায্য করবে

class RiceClassifier {
  Interpreter? _interpreter;
  List<String>? _labels;

  // ১. অ্যাপ বা পেজ চালুর সময় মডেল ও লেবেল ফাইল লোড করা
  Future<void> initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite');

      // labels.txt থেকে লাইনে লাইনে রোগের নাম পড়া
      final labelString = await rootBundle.loadString('assets/labels.txt');
      _labels = labelString.split('\n').map((e) => e.trim()).toList();

      print("মডেল এবং লেবেল সফলভাবে লোড হয়েছে!");
    } catch (e) {
      print("মডেল লোড করতে সমস্যা: $e");
    }
  }

  // ২. ছবিটিকে মডেলে পাঠানোর উপযোগী (224x224 Floating Matrix) করা
  List<List<List<List<double>>>> _preprocessImage(File imageFile) {
    var imageBytes = imageFile.readAsBytesSync();
    img.Image? originalImage = img.decodeImage(imageBytes);

    // আপনার ডাউনলোড করা মডেলের ইনপুট সাইজ অনুযায়ী (224x224) ছবি ছোট করা
    img.Image resizedImage = img.copyResize(
      originalImage!,
      width: 224,
      height: 224,
    );

    // [1, 224, 224, 3] ম্যাট্রিক্স তৈরি (মডেলের ইনপুট ফরম্যাট)
    var input = List.generate(
      1,
      (i) => List.generate(
        224,
        (j) => List.generate(224, (k) => List.filled(3, 0.0)),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // কালার ভ্যালু বা পিক্সেলকে ০ থেকে ১ এর মধ্যে নরমালাইজড করা
        input[0][y][x][0] = pixel.r / 255.0; // Red
        input[0][y][x][1] = pixel.g / 255.0; // Green
        input[0][y][x][2] = pixel.b / 255.0; // Blue
      }
    }
    return input;
  }

  // ৩. মূল রোগ ডিটেক্ট বা প্রেডিক্ট করার ফাংশন
  Map<String, dynamic>? classify(File imageFile) {
    if (_interpreter == null || _labels == null) return null;

    var input = _preprocessImage(imageFile);

    // টেক্সট ফাইলে ১০টি রোগ আছে, তাই আউটপুট বাফার হবে ১ লাইন ও ১০ কলামের
    var output = List.filled(1 * 10, 0.0).reshape([1, 10]);

    // এআই মডেল রান করা হচ্ছে
    _interpreter!.run(input, output);

    // ফলাফল থেকে সবচেয়ে বেশি সম্ভাবনা বা কনফিডেন্স কোন রোগের তা বের করা
    double maxScore = -1.0;
    int bestIndex = 0;

    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        bestIndex = i;
      }
    }

    return {
      'disease_name': _labels![bestIndex],
      'confidence': (maxScore * 100).toStringAsFixed(2), // শতকরায় রূপান্তর
    };
  }

  void dispose() {
    _interpreter?.close();
  }
}
