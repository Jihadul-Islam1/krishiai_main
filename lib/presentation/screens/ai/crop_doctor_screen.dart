import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/diagnosis.dart';
import '../../../data/models/disease.dart';

class CropDoctorScreen extends StatefulWidget {
  const CropDoctorScreen({super.key});

  @override
  State<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends State<CropDoctorScreen> {
  String? _imagePath;
  bool _loading = false;
  final Random _random = Random();

  // ডেমোর জন্য রোগের লিস্ট
  final List<Map<String, dynamic>> _mockDiseases = [
    {
      'name': 'পাতা ব্লাস্ট রোগ (Rice Blast)',
      'severity': Severity.high,
      'symptoms': [
        'পাতায় চোখ বা মাকু আকৃতির দাগ পড়ে',
        'দাগের কেন্দ্রস্থল ধূসর ও চারপাশ বাদামী হয়',
        'আক্রান্ত পাতা দ্রুত শুকিয়ে মরে যায়',
      ],
      'causes': [
        'ম্যাগনাপোর্টে ওরাইজি (Magnaporthe oryzae) ছত্রাক',
        'অতিরিক্ত নাইট্রোজেন সার ব্যবহার',
        'বাতাসে উচ্চ আর্দ্রতা ও শিশির',
      ],
      'prevention': [
        'রোগ প্রতিরোধী জাতের ধান চাষ করা',
        'সুষম মাত্রায় সার প্রয়োগ করা',
        'বীজ শোধন করে বপন করা',
      ],
      'management': [
        'ট্রাইসাইক্ল্যাজল (Tricyclazole) স্প্রে করুন',
        'জমিতে পানি ধরে রাখুন',
        'আক্রান্ত গাছ তুলে পুড়িয়ে ফেলুন',
      ],
    },
    {
      'name': 'ব্যাকটেরিয়াজনিত পাতা পোড়া (Bacterial Leaf Blight)',
      'severity': Severity.high,
      'symptoms': [
        'পাতার ডগা থেকে কিনারা ঘেঁষে হলুদ বা ধূসর দাগ',
        'আক্রান্ত অংশ ঢেউখেলানো হয়ে শুকিয়ে যায়',
        'সকালে পাতায় শিষের মতো ব্যাকটেরিয়ার ফোটা দেখা যায়',
      ],
      'causes': [
        'জ্যান্থোমোনাস ওরাইজি (Xanthomonas oryzae) ব্যাকটেরিয়া',
        'ঝড়-বৃষ্টি বা বাতাসের মাধ্যমে আক্রমণ',
        'নাইট্রোজেনের আধিক্য',
      ],
      'prevention': [
        'পটাশ সার সঠিক মাত্রায় ব্যবহার করা',
        'রোগমুক্ত সার্টিফাইড বীজ ব্যবহার করা',
      ],
      'management': [
        'কপার অক্সিক্লোরাইড ও স্ট্রেপ্টোসাইক্লিন স্প্রে করুন',
        'জমি থেকে অতিরিক্ত পানি বের করে দিন',
      ],
    },
    {
      'name': 'বাদামী দাগ রোগ (Brown Spot)',
      'severity': Severity.medium,
      'symptoms': [
        'পাতায় ছোট ছোট গোলাকার বা ডিম্বাকার বাদামী দাগ',
        'দাগের চারপাশে হলুদ বলয় থাকে',
        'ধানের দানাও দাগযুক্ত ও চিটা হতে পারে',
      ],
      'causes': [
        'বাইপোলারিস ওরাইজি (Bipolaris oryzae) ছত্রাক',
        'মাটিতে পটাশ ও পুষ্টির ঘাটতি',
        'দুর্বল সেচ ব্যবস্থা',
      ],
      'prevention': [
        'মাটির উর্বরতা বৃদ্ধি ও সুষম সার ব্যবহার',
        'সুস্থ ও নিরোগ বীজ নির্বাচন',
      ],
      'management': [
        'ম্যানকোজেব (Mancozeb) বা কার্বেনডাজিম স্প্রে করুন',
        'উপযুক্ত মাত্রায় পটাশ সার প্রয়োগ করুন',
      ],
    },
    {
      'name': 'খোল পচা রোগ (Sheath Rot)',
      'severity': Severity.medium,
      'symptoms': [
        'শীষের ওপরের খোলে ধূসর বা বাদামী চটকা দাগ',
        'শীষ পুরোপুরি বের হতে পারে না',
        'আক্রান্ত অংশ পচে গুঁড়ো বা সাদা ছত্রাক দেখা যায়',
      ],
      'causes': [
        'সারোক্ল্যাডিয়াম ওরাইজি (Sarocladium oryzae) ছত্রাক',
        'পোকামাকড়ের আক্রমণের কারণে সৃষ্ট ক্ষত',
      ],
      'prevention': ['জমি পরিচ্ছন্ন রাখা', 'পোকা দমন নিশ্চিত করা'],
      'management': [
        'প্রোপিকোনাজোল বা হেক্সাকোনাজোল জাতীয় ছত্রাকনাশক স্প্রে করুন',
      ],
    },
    {
      'name': 'সুস্থ ধান গাছ (Healthy Crop)',
      'severity': Severity.low,
      'symptoms': ['গাছ সতেজ ও সবুজ রয়েছে', 'কোনো ক্ষতিকর রোগের লক্ষণ নেই'],
      'causes': ['সঠিক পরিচর্যা ও সুষম পুষ্টি'],
      'prevention': ['নিয়মিত খেত পর্যবেক্ষণ করুন', 'সঠিক সময়ে সেচ ও সার দিন'],
      'management': ['কোনো রাসায়নিক ওষুধ ব্যবহারের প্রয়োজন নেই'],
    },
  ];

  // ছবি তোলা বা নির্বাচন
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  // ফেক প্রেডিকশন প্রসেস (র্যান্ডম ডাটা জেনারেটর)
  Future<void> _processAndNavigate() async {
    if (_imagePath == null) return;

    setState(() => _loading = true);

    // প্রেজেন্টেশনে আসল ভাব আনার জন্য ২ সেকেন্ড ডিলে করা হচ্ছে
    await Future.delayed(const Duration(seconds: 2));

    // র‍্যান্ডম রোগ ও কনফিডেন্স সিলেক্ট
    final randomDisease = _mockDiseases[_random.nextInt(_mockDiseases.length)];
    final randomConfidence =
        0.85 + (_random.nextDouble() * 0.13); // ০.৮৫ থেকে ০.৯৮

    final diagnosis = Diagnosis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cropName: 'ধান',
      diseaseName: randomDisease['name'] as String,
      confidence: double.parse(randomConfidence.toStringAsFixed(2)),
      severity: randomDisease['severity'] as Severity,
      scannedAt: DateTime.now(),
      symptoms: List<String>.from(randomDisease['symptoms'] as List),
      causes: List<String>.from(randomDisease['causes'] as List),
      prevention: List<String>.from(randomDisease['prevention'] as List),
      management: List<String>.from(randomDisease['management'] as List),
      imagePath: _imagePath,
    );

    if (mounted) {
      setState(() => _loading = false);
      context.push(
        '/ai/scan/result',
        extra: <String, dynamic>{
          'cropName': 'ধান',
          'diagnosis': diagnosis,
          'imagePath': _imagePath,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ধানের রোগ নির্ণয়'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 50,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'ছবি সিলেক্ট করতে ট্যাপ করুন',
                              style: AppTextStyles.bodyBold,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('ক্যামেরা'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('গ্যালারি'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: _loading
                  ? 'এআই দিয়ে বিশ্লেষণ করা হচ্ছে...'
                  : 'রোগ নির্ণয় করুন',
              icon: Icons.search_rounded,
              onPressed: (_imagePath == null || _loading)
                  ? null
                  : _processAndNavigate,
            ),
          ],
        ),
      ),
    );
  }
}
