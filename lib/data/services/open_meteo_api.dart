import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Thin wrapper around the **Open-Meteo** public forecast API.
///
/// Why Open-Meteo?
///   - Completely free, no API key, no signup.
///   - Returns current weather + 7-day forecast + hourly forecast in one
///     single HTTP request.
///   - Weather codes use the WMO standard — we map them to our local
///     `WeatherCondition` enum (sunny / cloudy / rainy / stormy / foggy /
///     partlyCloudy) which is what the UI consumes.
///
/// Reference: https://open-meteo.com/en/docs
class OpenMeteoApi {
  OpenMeteoApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://api.open-meteo.com/v1/forecast';

  final http.Client _client;

  /// Fetch weather for an arbitrary coordinate. Pass `label` (typically a
  /// district / locality resolved via `OsmService.reverse`) so the snapshot
  /// carries a human-readable location name. If you don't supply one the
  /// snapshot will fall back to "বর্তমান অবস্থান".
  Future<WeatherSnapshot> fetchByLatLon({
    required double lat,
    required double lon,
    String? label,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: <String, String>{
        'latitude': lat.toStringAsFixed(4),
        'longitude': lon.toStringAsFixed(4),
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation',
        'hourly':
            'temperature_2m,relative_humidity_2m,weather_code,precipitation_probability',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max',
        'timezone': _timezoneForCoords(lat, lon),
        'forecast_days': '7',
        'wind_speed_unit': 'kmh',
      },
    );

    final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw OpenMeteoException(
        'Open-Meteo request failed (${resp.statusCode}) for '
        '($lat, $lon).',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return _toSnapshot(body, label ?? 'বর্তমান অবস্থান');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Pick the best IANA timezone string for the coordinate. Open-Meteo
  /// accepts "auto" which resolves on their side, but we want to avoid the
  /// extra dependency and just send a sensible default for the regions we
  /// support (Bangladesh + India + globe).
  String _timezoneForCoords(double lat, double lon) {
    // Bangladesh
    if (lat >= 20.5 && lat <= 26.5 && lon >= 88.0 && lon <= 92.5) {
      return 'Asia/Dhaka';
    }
    // India
    if (lat >= 6.5 && lat <= 36.0 && lon >= 68.0 && lon <= 98.0) {
      return 'Asia/Kolkata';
    }
    return 'auto';
  }

  WeatherSnapshot _toSnapshot(Map<String, dynamic> body, String location) {
    final current = (body['current'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hourly = (body['hourly'] as Map?)?.cast<String, dynamic>() ?? const {};
    final daily = (body['daily'] as Map?)?.cast<String, dynamic>() ?? const {};

    final tempC = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
    final humidityRaw = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0;
    final humidity = (humidityRaw / 100.0).clamp(0.0, 1.0);
    final windKmh = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
    final precipMm = (current['precipitation'] as num?)?.toDouble() ?? 0;
    final cond = _conditionFromWmo(
      (current['weather_code'] as num?)?.toInt() ?? 0,
    );
    final updatedAt = DateTime.now().toUtc();

    // -------- Hourly (next 24) -------------------------------------------
    final hourlyList = _buildHourly(hourly, fallbackTempC: tempC, fallbackHumidity: humidity);

    // -------- Daily (7 days) ---------------------------------------------
    final dailyList = _buildDaily(daily, fallbackTempC: tempC, fallbackHumidity: humidity);

    // Rain probability: derive from the next ~6 hours of `precipitation_probability`
    // if present, else approximate from current precipitation magnitude.
    final rainProb = _rainProbFromHourly(hourlyList);

    return WeatherSnapshot(
      location: location,
      currentTempC: tempC,
      condition: cond,
      rainProbability: rainProb,
      humidity: humidity,
      windKmh: windKmh,
      updatedAt: updatedAt,
      hourly: hourlyList,
      daily: dailyList,
      agronomyAdvice: _agronomyNote(
        condition: cond,
        tempC: tempC,
        humidity: humidity,
        windKmh: windKmh,
        precipMm: precipMm,
      ),
    );
  }

  List<HourlyForecast> _buildHourly(
    Map<String, dynamic> hourly, {
    required double fallbackTempC,
    required double fallbackHumidity,
  }) {
    final times = (hourly['time'] as List?)?.cast<String>() ?? const [];
    final temps = (hourly['temperature_2m'] as List?)?.cast<num>() ?? const [];
    final hums = (hourly['relative_humidity_2m'] as List?)?.cast<num>() ?? const [];
    final codes = (hourly['weather_code'] as List?)?.cast<num>() ?? const [];
    final pops = (hourly['precipitation_probability'] as List?)?.cast<num>() ?? const [];

    final now = DateTime.now();
    final out = <HourlyForecast>[];
    for (var i = 0; i < times.length && out.length < 24; i++) {
      final t = DateTime.tryParse(times[i]);
      if (t == null) continue;
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      out.add(
        HourlyForecast(
          time: t,
          tempC: i < temps.length ? temps[i].toDouble() : fallbackTempC,
          condition: i < codes.length
              ? _conditionFromWmo(codes[i].toInt())
              : WeatherCondition.partlyCloudy,
          rainProbability:
              i < pops.length ? (pops[i].toDouble() / 100.0).clamp(0.0, 1.0) : 0,
          humidity: i < hums.length
              ? (hums[i].toDouble() / 100.0).clamp(0.0, 1.0)
              : fallbackHumidity,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        HourlyForecast(
          time: now,
          tempC: fallbackTempC,
          condition: WeatherCondition.partlyCloudy,
          rainProbability: 0,
          humidity: fallbackHumidity,
        ),
      );
    }
    return out;
  }

  List<DailyForecast> _buildDaily(
    Map<String, dynamic> daily, {
    required double fallbackTempC,
    required double fallbackHumidity,
  }) {
    final days = (daily['time'] as List?)?.cast<String>() ?? const [];
    final codes = (daily['weather_code'] as List?)?.cast<num>() ?? const [];
    final maxT = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? const [];
    final minT = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? const [];
    final pops = (daily['precipitation_probability_max'] as List?)?.cast<num>() ?? const [];
    final winds = (daily['wind_speed_10m_max'] as List?)?.cast<num>() ?? const [];

    final out = <DailyForecast>[];
    for (var i = 0; i < days.length && out.length < 7; i++) {
      final d = DateTime.tryParse('${days[i]}T12:00:00') ?? DateTime.now();
      out.add(
        DailyForecast(
          date: d,
          maxTempC: i < maxT.length ? maxT[i].toDouble() : fallbackTempC,
          minTempC: i < minT.length ? minT[i].toDouble() : fallbackTempC,
          condition: i < codes.length
              ? _conditionFromWmo(codes[i].toInt())
              : WeatherCondition.partlyCloudy,
          rainProbability:
              i < pops.length ? (pops[i].toDouble() / 100.0).clamp(0.0, 1.0) : 0,
          humidity: fallbackHumidity,
          windKmh: i < winds.length ? winds[i].toDouble() : 0,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        DailyForecast(
          date: DateTime.now(),
          maxTempC: fallbackTempC,
          minTempC: fallbackTempC,
          condition: WeatherCondition.partlyCloudy,
          rainProbability: 0,
          humidity: fallbackHumidity,
          windKmh: 0,
        ),
      );
    }
    return out;
  }

  double _rainProbFromHourly(List<HourlyForecast> hourly) {
    if (hourly.isEmpty) return 0;
    // Look at the next 6 hours and take the max POP.
    final window = hourly.take(6).map((h) => h.rainProbability);
    return window.fold<double>(0, (a, b) => a > b ? a : b);
  }

  /// WMO weather code → local `WeatherCondition`. Subset that covers
  /// 95%+ of the codes Open-Meteo returns in Bangladesh. Anything we
  /// don't recognise falls back to partlyCloudy.
  WeatherCondition _conditionFromWmo(int code) {
    // 0            : Clear sky
    // 1, 2         : Mainly clear / partly cloudy
    // 3            : Overcast
    // 45, 48       : Fog
    // 51, 53, 55   : Drizzle (light / moderate / dense)
    // 56, 57       : Freezing drizzle
    // 61-65        : Rain (slight / moderate / heavy)
    // 66, 67       : Freezing rain
    // 71-75        : Snow fall
    // 77           : Snow grains
    // 80-82        : Rain showers
    // 85, 86       : Snow showers
    // 95           : Thunderstorm
    // 96, 99       : Thunderstorm with hail
    if (code == 0) return WeatherCondition.sunny;
    if (code == 1 || code == 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.cloudy;
    if (code == 45 || code == 48) return WeatherCondition.foggy;
    if (code >= 51 && code <= 67) return WeatherCondition.rainy;
    if (code >= 71 && code <= 86) return WeatherCondition.rainy;
    if (code >= 80 && code <= 82) return WeatherCondition.rainy;
    if (code >= 95) return WeatherCondition.stormy;
    return WeatherCondition.partlyCloudy;
  }

  /// Short Bangla agronomy advisory based on the live numbers. UI shows
  /// this as the "💡 পরামর্শ" card on the weather screen.
  String _agronomyNote({
    required WeatherCondition condition,
    required double tempC,
    required double humidity,
    required double windKmh,
    required double precipMm,
  }) {
    if (condition == WeatherCondition.stormy || precipMm >= 5) {
      return 'আজ ঝড়/ভারী বৃষ্টির সম্ভাবনা — ফসল তোলা বা স্প্রে করা এড়িয়ে চলুন।';
    }
    if (condition == WeatherCondition.rainy) {
      return 'বৃষ্টি হতে পারে — সেচ স্থগিত রাখুন, ফসল ঢেকে রাখুন।';
    }
    if (tempC >= 34 && humidity < 0.5) {
      return 'প্রচণ্ড গরম ও শুষ্ক — সকালে/সন্ধ্যায় সেচ দিন, মালচিং ব্যবহার করুন।';
    }
    if (tempC <= 15) {
      return 'তাপমাত্রা কম — শীতকালীন ফসলের জন্য উপযুক্ত, তবে বরফ/কুয়াশা থেকে রক্ষা করুন।';
    }
    if (windKmh >= 30) {
      return 'উচ্চ বাতাস — উঁচু ফসলের ভারসাম্য রক্ষা করুন, কীটনাশক স্প্রে এড়িয়ে চলুন।';
    }
    if (humidity >= 0.85 && condition != WeatherCondition.rainy) {
      return 'আর্দ্রতা বেশি — ছত্রাকজনিত রোগের ঝুঁকি, নিয়মিত বাগান পরীক্ষা করুন।';
    }
    return 'আবহাওয়া চাষের জন্য অনুকূল — স্বাভাবিক কৃষি কার্যক্রম চালিয়ে যান।';
  }
}

/// Thrown when Open-Meteo can't be reached or returns a non-200.
class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);
  final String message;

  @override
  String toString() => 'OpenMeteoException: $message';
}

// ignore: unused_element
bool _isMobilePlatform() {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}