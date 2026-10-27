import 'package:flutter/foundation.dart';

import 'disease.dart';

/// Another class the model considered, shown when the top guess is unsure.
@immutable
class DiagnosisCandidate {
  const DiagnosisCandidate({required this.name, required this.confidence});

  final String name;
  final double confidence;

  Map<String, dynamic> toJson() => {'name': name, 'confidence': confidence};

  factory DiagnosisCandidate.fromJson(Map<String, dynamic> json) =>
      DiagnosisCandidate(
        name: json['name'] as String,
        confidence: (json['confidence'] as num).toDouble(),
      );
}

@immutable
class Diagnosis {
  const Diagnosis({
    required this.id,
    required this.cropName,
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.scannedAt,
    required this.symptoms,
    required this.causes,
    required this.management,
    required this.prevention,
    this.imagePath,
    this.cropId,
    this.notes,
    this.fertilizer = const [],
    this.alternatives = const [],
    this.isConfident,
  });

  final String id;
  final String cropName;
  final String diseaseName;
  final double confidence;
  final Severity severity;
  final DateTime scannedAt;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> management;
  final List<String> prevention;
  final String? imagePath;
  final String? cropId;
  final String? notes;
  final List<String> fertilizer;
  final List<DiagnosisCandidate> alternatives;

  /// The model's verdict at scan time (server or on-device thresholds).
  /// Null for scans saved before this was recorded.
  final bool? isConfident;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cropName': cropName,
    'diseaseName': diseaseName,
    'confidence': confidence,
    'severity': severity.key,
    'scannedAt': scannedAt.toIso8601String(),
    'symptoms': symptoms,
    'causes': causes,
    'management': management,
    'prevention': prevention,
    'imagePath': imagePath,
    'cropId': cropId,
    'notes': notes,
    'fertilizer': fertilizer,
    'alternatives': alternatives.map((a) => a.toJson()).toList(),
    'isConfident': isConfident,
  };

  factory Diagnosis.fromJson(Map<String, dynamic> json) => Diagnosis(
    id: json['id'] as String,
    cropName: json['cropName'] as String,
    diseaseName: json['diseaseName'] as String,
    confidence: (json['confidence'] as num).toDouble(),
    severity: Severity.values.firstWhere(
      (e) => e.key == (json['severity'] as String? ?? 'medium'),
      orElse: () => Severity.medium,
    ),
    scannedAt: DateTime.parse(json['scannedAt'] as String),
    symptoms: List<String>.from(json['symptoms'] as List? ?? const []),
    causes: List<String>.from(json['causes'] as List? ?? const []),
    management: List<String>.from(json['management'] as List? ?? const []),
    prevention: List<String>.from(json['prevention'] as List? ?? const []),
    imagePath: json['imagePath'] as String?,
    cropId: json['cropId'] as String?,
    notes: json['notes'] as String?,
    fertilizer: List<String>.from(json['fertilizer'] as List? ?? const []),
    alternatives: (json['alternatives'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiagnosisCandidate.fromJson)
        .toList(),
    isConfident: json['isConfident'] as bool?,
  );
}
