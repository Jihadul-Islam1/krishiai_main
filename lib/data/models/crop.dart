import 'package:flutter/foundation.dart';

import 'farm.dart';

enum CropStage {
  planted,
  earlyGrowth,
  vegetative,
  flowering,
  fruiting,
  harvestReady,
  harvested,
}

extension CropStageX on CropStage {
  String get bangla {
    switch (this) {
      case CropStage.planted:
        return 'রোপণ';
      case CropStage.earlyGrowth:
        return 'প্রাথমিক বৃদ্ধি';
      case CropStage.vegetative:
        return 'সবুজ শাখা-প্রশাখা';
      case CropStage.flowering:
        return 'ফুল ফোটা';
      case CropStage.fruiting:
        return 'ফল ধারণ';
      case CropStage.harvestReady:
        return 'সংগ্রহের উপযুক্ত';
      case CropStage.harvested:
        return 'সংগ্রহ সম্পন্ন';
    }
  }

  String get key => name;
}

enum IrrigationType { rainfed, manual, drip, sprinkler, flood }

extension IrrigationTypeX on IrrigationType {
  String get bangla {
    switch (this) {
      case IrrigationType.rainfed:
        return 'বৃষ্টিনির্ভর';
      case IrrigationType.manual:
        return 'হাতে সেচ';
      case IrrigationType.drip:
        return 'ড্রিপ সেচ';
      case IrrigationType.sprinkler:
        return 'স্প্রিংকলার';
      case IrrigationType.flood:
        return 'বন্যা সেচ';
    }
  }

  String get key => name;
}

@immutable
class Crop {
  const Crop({
    required this.id,
    required this.farmId,
    required this.name,
    required this.variety,
    required this.plantingDate,
    required this.landSizeAcres,
    required this.soilType,
    required this.irrigation,
    required this.expectedHarvestDate,
    required this.stage,
    this.estimatedYieldKg,
    this.notes,
  });

  final String id;
  final String farmId;
  final String name;
  final String variety;
  final DateTime plantingDate;
  final double landSizeAcres;
  final SoilType soilType;
  final IrrigationType irrigation;
  final DateTime expectedHarvestDate;
  final CropStage stage;
  final double? estimatedYieldKg;
  final String? notes;

  int get daysSincePlanting =>
      DateTime.now().difference(plantingDate).inDays.clamp(0, 10000);

  Crop copyWith({
    String? name,
    String? variety,
    DateTime? plantingDate,
    double? landSizeAcres,
    SoilType? soilType,
    IrrigationType? irrigation,
    DateTime? expectedHarvestDate,
    CropStage? stage,
    double? estimatedYieldKg,
    String? notes,
  }) {
    return Crop(
      id: id,
      farmId: farmId,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      plantingDate: plantingDate ?? this.plantingDate,
      landSizeAcres: landSizeAcres ?? this.landSizeAcres,
      soilType: soilType ?? this.soilType,
      irrigation: irrigation ?? this.irrigation,
      expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
      stage: stage ?? this.stage,
      estimatedYieldKg: estimatedYieldKg ?? this.estimatedYieldKg,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'farmId': farmId,
    'name': name,
    'variety': variety,
    'plantingDate': plantingDate.toIso8601String(),
    'landSizeAcres': landSizeAcres,
    'soilType': soilType.key,
    'irrigation': irrigation.key,
    'expectedHarvestDate': expectedHarvestDate.toIso8601String(),
    'stage': stage.key,
    'estimatedYieldKg': estimatedYieldKg,
    'notes': notes,
  };

  factory Crop.fromJson(Map<String, dynamic> json) => Crop(
    id: json['id'] as String,
    farmId: json['farmId'] as String,
    name: json['name'] as String,
    variety: json['variety'] as String? ?? '',
    plantingDate: DateTime.parse(json['plantingDate'] as String),
    landSizeAcres: (json['landSizeAcres'] as num).toDouble(),
    soilType: SoilType.values.firstWhere(
      (e) => e.key == (json['soilType'] as String? ?? 'unknown'),
      orElse: () => SoilType.unknown,
    ),
    irrigation: IrrigationType.values.firstWhere(
      (e) => e.key == (json['irrigation'] as String? ?? 'rainfed'),
      orElse: () => IrrigationType.rainfed,
    ),
    expectedHarvestDate: DateTime.parse(json['expectedHarvestDate'] as String),
    stage: CropStage.values.firstWhere(
      (e) => e.key == (json['stage'] as String? ?? 'planted'),
      orElse: () => CropStage.planted,
    ),
    estimatedYieldKg: (json['estimatedYieldKg'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
  );
}
