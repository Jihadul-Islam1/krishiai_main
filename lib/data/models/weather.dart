import 'package:flutter/foundation.dart';

enum WeatherCondition { sunny, cloudy, rainy, stormy, foggy, partlyCloudy }

extension WeatherConditionX on WeatherCondition {
  String get bangla {
    switch (this) {
      case WeatherCondition.sunny:
        return 'রোদ';
      case WeatherCondition.cloudy:
        return 'মেঘলা';
      case WeatherCondition.rainy:
        return 'বৃষ্টি';
      case WeatherCondition.stormy:
        return 'ঝড়';
      case WeatherCondition.foggy:
        return 'কুয়াশা';
      case WeatherCondition.partlyCloudy:
        return 'রোদ-মেঘলা';
    }
  }

  String get key => name;
}

@immutable
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.condition,
    required this.rainProbability,
    required this.humidity,
  });

  final DateTime time;
  final double tempC;
  final WeatherCondition condition;
  final double rainProbability;
  final double humidity;
}

@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.condition,
    required this.rainProbability,
    required this.humidity,
    required this.windKmh,
  });

  final DateTime date;
  final double maxTempC;
  final double minTempC;
  final WeatherCondition condition;
  final double rainProbability;
  final double humidity;
  final double windKmh;
}

@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.currentTempC,
    required this.condition,
    required this.rainProbability,
    required this.humidity,
    required this.windKmh,
    required this.updatedAt,
    required this.hourly,
    required this.daily,
    required this.agronomyAdvice,
  });

  final String location;
  final double currentTempC;
  final WeatherCondition condition;
  final double rainProbability;
  final double humidity;
  final double windKmh;
  final DateTime updatedAt;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final String agronomyAdvice;
}
