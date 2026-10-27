import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/library/crop_disease_info.dart';
import '../../../data/library/eggplant_disease_info.dart';
import '../../../data/library/maize_disease_info.dart';
import '../../../data/library/potato_disease_info.dart';
import '../../../data/library/rice_disease_info.dart';
import '../../../data/library/tomato_disease_info.dart';

/// How a crop's photos are diagnosed.
enum DetectionMode {
  /// Model bundled in the app; works without internet.
  offline,

  /// Photo goes to the inference server (`ml_backend`); keeps the app small.
  online,
}

/// A crop the Crop Doctor can diagnose, with its look on screen.
@immutable
class DoctorCrop {
  const DoctorCrop({
    required this.id,
    required this.nameBn,
    required this.possessiveBn,
    required this.emoji,
    required this.mode,
    required this.color,
    required this.deepColor,
    required this.tint,
    required this.diseases,
    required this.healthyLabel,
  });

  /// Sent to the server as the `crop` form field; also `?crop=` in the route.
  final String id;
  final String nameBn;

  /// "ধানের", "আলুর" — for phrases like "ধানের পাতার ছবি দিন".
  final String possessiveBn;
  final String emoji;
  final DetectionMode mode;

  /// Accent for buttons and the selected tile (white text must read on it).
  final Color color;

  /// Darker start of the hero gradient.
  final Color deepColor;

  /// Soft background behind the crop's emoji and photo slot.
  final Color tint;

  /// Advisory per model label; keys must match what the model returns.
  final Map<String, CropDiseaseInfo> diseases;
  final String healthyLabel;

  bool get isOnline => mode == DetectionMode.online;

  Iterable<CropDiseaseInfo> get problems =>
      diseases.entries.where((e) => e.key != healthyLabel).map((e) => e.value);

  static DoctorCrop byId(String? id) => doctorCrops.firstWhere(
    (c) => c.id == id,
    orElse: () => doctorCrops.first,
  );

  /// Saved diagnoses only store the Bangla crop name.
  static DoctorCrop byName(String name) => doctorCrops.firstWhere(
    (c) => c.nameBn == name,
    orElse: () => doctorCrops.first,
  );
}

const doctorCrops = <DoctorCrop>[
  DoctorCrop(
    id: 'rice',
    nameBn: 'ধান',
    possessiveBn: 'ধানের',
    emoji: '🌾',
    mode: DetectionMode.offline,
    color: AppColors.primary,
    deepColor: AppColors.fieldCard,
    tint: AppColors.primaryContainer,
    diseases: riceDiseaseInfo,
    healthyLabel: 'Healthy Rice Leaf',
  ),
  DoctorCrop(
    id: 'potato',
    nameBn: 'আলু',
    possessiveBn: 'আলুর',
    emoji: '🥔',
    mode: DetectionMode.online,
    color: Color(0xFF9C5B21),
    deepColor: Color(0xFF4A2B10),
    tint: Color(0xFFFBF1E6),
    diseases: potatoDiseaseInfo,
    healthyLabel: 'healthy',
  ),
  DoctorCrop(
    id: 'tomato',
    nameBn: 'টমেটো',
    possessiveBn: 'টমেটোর',
    emoji: '🍅',
    mode: DetectionMode.online,
    color: Color(0xFFDC2626),
    deepColor: Color(0xFF7F1D1D),
    tint: Color(0xFFFDECEC),
    diseases: tomatoDiseaseInfo,
    healthyLabel: 'healthy',
  ),
  DoctorCrop(
    id: 'eggplant',
    nameBn: 'বেগুন',
    possessiveBn: 'বেগুনের',
    emoji: '🍆',
    mode: DetectionMode.online,
    color: Color(0xFF7C3AED),
    deepColor: Color(0xFF3B0764),
    tint: Color(0xFFF3EDFF),
    diseases: eggplantDiseaseInfo,
    healthyLabel: 'healthy',
  ),
  DoctorCrop(
    id: 'maize',
    nameBn: 'ভুট্টা',
    possessiveBn: 'ভুট্টার',
    emoji: '🌽',
    mode: DetectionMode.online,
    color: Color(0xFFA16207),
    deepColor: Color(0xFF52360A),
    tint: Color(0xFFFEF6DA),
    diseases: maizeDiseaseInfo,
    healthyLabel: 'healthy',
  ),
];
