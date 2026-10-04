import '../models/weather.dart';

/// Deterministic demo dataset used while the backend is mocked.
class DemoData {
  const DemoData._();

  /// Returns a representative Khulna-area weather snapshot.
  static WeatherSnapshot demoWeather() {
    final now = DateTime.now();
    return WeatherSnapshot(
      location: 'খুলনা',
      currentTempC: 31.4,
      condition: WeatherCondition.partlyCloudy,
      rainProbability: 0.35,
      humidity: 0.72,
      windKmh: 12.0,
      updatedAt: now,
      agronomyAdvice:
          'আজ হালকা মেঘলা আকাশ ও ৩৫% বৃষ্টির সম্ভাবনা। বিকেলে সেচ দেওয়া এড়িয়ে চলুন।',
      hourly: List<HourlyForecast>.generate(8, (i) {
        final t = now.add(Duration(hours: i + 1));
        return HourlyForecast(
          time: t,
          tempC: 30 - (i * 0.4),
          condition: i < 3
              ? WeatherCondition.partlyCloudy
              : WeatherCondition.sunny,
          rainProbability: 0.35 - (i * 0.03),
          humidity: 0.72 - (i * 0.01),
        );
      }),
      daily: List<DailyForecast>.generate(7, (i) {
        final d = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        return DailyForecast(
          date: d,
          maxTempC: 33 - (i % 2),
          minTempC: 24 + (i % 2),
          condition: i % 3 == 0
              ? WeatherCondition.rainy
              : WeatherCondition.partlyCloudy,
          rainProbability: i % 3 == 0 ? 0.7 : 0.2,
          humidity: 0.7,
          windKmh: 10.0 + i,
        );
      }),
    );
  }
}
