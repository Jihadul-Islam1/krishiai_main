import 'package:flutter/foundation.dart';

@immutable
class ProfitEstimate {
  const ProfitEstimate({
    required this.cropName,
    required this.landSizeAcres,
    required this.estimatedProductionKg,
    required this.sellingPricePerKg,
    required this.totalCost,
    this.id = '',
    this.savedAt,
  });

  final String id;
  final DateTime? savedAt;

  final String cropName;
  final double landSizeAcres;
  final double estimatedProductionKg;
  final double sellingPricePerKg;
  final double totalCost;

  double get estimatedRevenue => estimatedProductionKg * sellingPricePerKg;
  double get estimatedProfit => estimatedRevenue - totalCost;
  bool get isProfitable => estimatedProfit > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cropName': cropName,
    'landSizeAcres': landSizeAcres,
    'estimatedProductionKg': estimatedProductionKg,
    'sellingPricePerKg': sellingPricePerKg,
    'totalCost': totalCost,
    'estimatedRevenue': estimatedRevenue,
    'estimatedProfit': estimatedProfit,
    'savedAt': savedAt?.toIso8601String(),
  };

  factory ProfitEstimate.fromJson(Map<String, dynamic> json) => ProfitEstimate(
    id: json['id'] as String? ?? '',
    cropName: json['cropName'] as String? ?? '',
    landSizeAcres: (json['landSizeAcres'] as num?)?.toDouble() ?? 0,
    estimatedProductionKg:
        (json['estimatedProductionKg'] as num?)?.toDouble() ?? 0,
    sellingPricePerKg: (json['sellingPricePerKg'] as num?)?.toDouble() ?? 0,
    totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
    savedAt: json['savedAt'] is String
        ? DateTime.tryParse(json['savedAt'] as String)
        : null,
  );
}
