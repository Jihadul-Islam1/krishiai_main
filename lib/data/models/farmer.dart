import 'package:flutter/foundation.dart';

@immutable
class Farmer {
  const Farmer({
    required this.id,
    required this.name,
    required this.district,
    required this.upazila,
    required this.experienceYears,
    required this.farmSizeAcres,
    required this.mainCrop,
    required this.language,
    this.profileImagePath,
    this.createdAt,
  });

  final String id;
  final String name;
  final String district;
  final String upazila;
  final int experienceYears;
  final double farmSizeAcres;
  final String mainCrop;
  final String language;
  final String? profileImagePath;
  final DateTime? createdAt;

  Farmer copyWith({
    String? name,
    String? district,
    String? upazila,
    int? experienceYears,
    double? farmSizeAcres,
    String? mainCrop,
    String? language,
    String? profileImagePath,
  }) {
    return Farmer(
      id: id,
      name: name ?? this.name,
      district: district ?? this.district,
      upazila: upazila ?? this.upazila,
      experienceYears: experienceYears ?? this.experienceYears,
      farmSizeAcres: farmSizeAcres ?? this.farmSizeAcres,
      mainCrop: mainCrop ?? this.mainCrop,
      language: language ?? this.language,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'district': district,
    'upazila': upazila,
    'experienceYears': experienceYears,
    'farmSizeAcres': farmSizeAcres,
    'mainCrop': mainCrop,
    'language': language,
    'profileImagePath': profileImagePath,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
    id: json['id'] as String,
    name: json['name'] as String,
    district: json['district'] as String,
    upazila: json['upazila'] as String,
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    farmSizeAcres: (json['farmSizeAcres'] as num?)?.toDouble() ?? 0.0,
    mainCrop: json['mainCrop'] as String? ?? '',
    language: json['language'] as String? ?? 'bn',
    profileImagePath: json['profileImagePath'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );
}
