import 'package:flutter/foundation.dart';

enum RecommendationType {
  irrigation,
  pest,
  weather,
  fertilizer,
  monitoring,
  harvest,
}

extension RecommendationTypeX on RecommendationType {
  String get bangla {
    switch (this) {
      case RecommendationType.irrigation:
        return 'সেচ';
      case RecommendationType.pest:
        return 'কীটপতঙ্গ';
      case RecommendationType.weather:
        return 'আবহাওয়া';
      case RecommendationType.fertilizer:
        return 'সার';
      case RecommendationType.monitoring:
        return 'পর্যবেক্ষণ';
      case RecommendationType.harvest:
        return 'সংগ্রহ';
    }
  }

  String get key => name;
}

@immutable
class Recommendation {
  const Recommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.cropId,
  });

  final String id;
  final RecommendationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? cropId;
}
