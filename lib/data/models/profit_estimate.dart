import 'package:flutter/foundation.dart';

@immutable
class ProfitEstimate {
  const ProfitEstimate({
    required this.cropName,
    required this.landSizeAcres,
    required this.estimatedProductionKg,
    required this.sellingPricePerKg,
    required this.totalCost,
  });

  final String cropName;
  final double landSizeAcres;
  final double estimatedProductionKg;
  final double sellingPricePerKg;
  final double totalCost;

  double get estimatedRevenue => estimatedProductionKg * sellingPricePerKg;
  double get estimatedProfit => estimatedRevenue - totalCost;
  bool get isProfitable => estimatedProfit > 0;
}
