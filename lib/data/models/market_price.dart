import 'package:flutter/foundation.dart';

enum PriceTrend { up, down, stable }

extension PriceTrendX on PriceTrend {
  String get bangla {
    switch (this) {
      case PriceTrend.up:
        return 'বাড়তি';
      case PriceTrend.down:
        return 'কমতি';
      case PriceTrend.stable:
        return 'স্থিতিশীল';
    }
  }

  String get key => name;
}

@immutable
class PricePoint {
  const PricePoint({required this.date, required this.price});
  final DateTime date;
  final double price;
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'price': price};
  factory PricePoint.fromJson(Map<String, dynamic> j) =>
      PricePoint(date: DateTime.parse(j['date'] as String), price: (j['price'] as num).toDouble());
}

@immutable
class MarketPrice {
  const MarketPrice({
    required this.id,
    required this.cropName,
    required this.market,
    required this.unit,
    required this.currentPrice,
    required this.previousPrice,
    required this.updatedAt,
    required this.source,
    this.isFavorite = false,
    this.history = const <PricePoint>[],
    this.category = '',
    this.minPrice,
    this.maxPrice,
  });

  final String id;
  final String cropName;
  final String market;
  final String unit;
  final double currentPrice;
  final double previousPrice;
  final DateTime updatedAt;
  final String source;
  final bool isFavorite;
  final List<PricePoint> history;
  final String category;
  final double? minPrice;
  final double? maxPrice;

  PriceTrend get trend {
    final delta = currentPrice - previousPrice;
    if (delta > 0.5) return PriceTrend.up;
    if (delta < -0.5) return PriceTrend.down;
    return PriceTrend.stable;
  }

  double get changePercent => previousPrice == 0
      ? 0
      : ((currentPrice - previousPrice) / previousPrice) * 100;

  MarketPrice copyWith({
    double? currentPrice,
    double? previousPrice,
    DateTime? updatedAt,
    bool? isFavorite,
    List<PricePoint>? history,
    double? minPrice,
    double? maxPrice,
  }) {
    return MarketPrice(
      id: id,
      cropName: cropName,
      market: market,
      unit: unit,
      currentPrice: currentPrice ?? this.currentPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source,
      isFavorite: isFavorite ?? this.isFavorite,
      history: history ?? this.history,
      category: category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cropName': cropName,
        'market': market,
        'unit': unit,
        'currentPrice': currentPrice,
        'previousPrice': previousPrice,
        'updatedAt': updatedAt.toIso8601String(),
        'source': source,
        'isFavorite': isFavorite,
        'history': history.map((p) => p.toJson()).toList(),
        'category': category,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
      };

  factory MarketPrice.fromJson(Map<String, dynamic> json) => MarketPrice(
        id: json['id'] as String,
        cropName: json['cropName'] as String,
        market: json['market'] as String? ?? 'ঢাকা',
        unit: json['unit'] as String? ?? 'কেজি',
        currentPrice: (json['currentPrice'] as num).toDouble(),
        previousPrice: (json['previousPrice'] as num?)?.toDouble() ??
            (json['currentPrice'] as num).toDouble(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        source: json['source'] as String? ?? 'DAM',
        isFavorite: json['isFavorite'] as bool? ?? false,
        history: ((json['history'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PricePoint.fromJson)
            .toList(),
        category: json['category'] as String? ?? '',
        minPrice: (json['minPrice'] as num?)?.toDouble(),
        maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      );
}

