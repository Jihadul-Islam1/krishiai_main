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
    this.phone = '',
    this.village = '',
    this.soilType = '',
    this.irrigationSource = '',
    this.profileImagePath,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String district;
  final String upazila;
  final int experienceYears;
  final double farmSizeAcres;
  final String mainCrop;
  final String language;

  /// Login phone number (E.164, e.g. +8801812345678) - also the Firestore
  /// document key under `users/{phone}`.
  final String phone;
  final String village;
  final String soilType;
  final String irrigationSource;
  final String? profileImagePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Farmer copyWith({
    String? name,
    String? district,
    String? upazila,
    int? experienceYears,
    double? farmSizeAcres,
    String? mainCrop,
    String? language,
    String? phone,
    String? village,
    String? soilType,
    String? irrigationSource,
    String? profileImagePath,
    bool clearProfileImage = false,
    DateTime? updatedAt,
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
      phone: phone ?? this.phone,
      village: village ?? this.village,
      soilType: soilType ?? this.soilType,
      irrigationSource: irrigationSource ?? this.irrigationSource,
      profileImagePath: clearProfileImage
          ? null
          : (profileImagePath ?? this.profileImagePath),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    'phone': phone,
    'village': village,
    'soilType': soilType,
    'irrigationSource': irrigationSource,
    'profileImagePath': profileImagePath,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    district: json['district'] as String? ?? '',
    upazila: json['upazila'] as String? ?? '',
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    farmSizeAcres: (json['farmSizeAcres'] as num?)?.toDouble() ?? 0.0,
    mainCrop: json['mainCrop'] as String? ?? '',
    language: json['language'] as String? ?? 'bn',
    phone: json['phone'] as String? ?? '',
    village: json['village'] as String? ?? '',
    soilType: json['soilType'] as String? ?? '',
    irrigationSource: json['irrigationSource'] as String? ?? '',
    profileImagePath: json['profileImagePath'] as String?,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  static DateTime? _date(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
