import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/weather.dart';

/// Thin wrapper around the OpenWeatherMap **free-tier** endpoints:
///  * `/data/2.5/weather`     — current observation
///  * `/data/2.5/forecast`   — 5-day / 3-hour forecast (translated into a
///                              7-day rolling window for the UI)
///
/// The repository decides whether to call us at all — if the user has not
/// supplied an API key we short-circuit and the repo falls back to demo
/// data. Keeping the API surface small & async-friendly lets us swap to a
/// different provider later without touching the repository.
class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://api.openweathermap.org';

  final http.Client _client;

  /// Whether the dotenv file actually provided a non-empty API key.
  bool get hasKey {
    final key = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
    return key.isNotEmpty && key != 'PUT_YOUR_KEY_HERE';
  }

  /// Resolve a Bangla/English district name to a (lat, lon) pair. We hard-code
  /// the major Bangladeshi districts that the app is currently demo'd against;
  /// anything else falls back to Dhaka so the app never crashes on an unknown
  /// district (matches the pre-existing repository contract).
  ({double lat, double lon}) coordsFor(String district) {
    const map = <String, ({double lat, double lon})>{
      'khulna': (lat: 22.8456, lon: 89.5403),
      'খুলনা': (lat: 22.8456, lon: 89.5403),
      'dhaka': (lat: 23.8103, lon: 90.4125),
      'ঢাকা': (lat: 23.8103, lon: 90.4125),
      'rajshahi': (lat: 24.3745, lon: 88.6042),
      'রাজশাহী': (lat: 24.3745, lon: 88.6042),
      'chittagong': (lat: 22.3569, lon: 91.7832),
      'চট্টগ্রাম': (lat: 22.3569, lon: 91.7832),
      'sylhet': (lat: 24.8949, lon: 91.8687),
      'সিলেট': (lat: 24.8949, lon: 91.8687),
      'rangpur': (lat: 25.7439, lon: 89.2752),
      'রংপুর': (lat: 25.7439, lon: 89.2752),
      'barisal': (lat: 22.7010, lon: 90.3695),
      'বরিশাল': (lat: 22.7010, lon: 90.3695),
      'mymensingh': (lat: 24.7471, lon: 90.4203),
      'ময়মনসিংহ': (lat: 24.7471, lon: 90.4203),
      'gazipur': (lat: 23.9999, lon: 90.4203),
      'গাজীপুর': (lat: 23.9999, lon: 90.4203),
      'narayanganj': (lat: 23.6238, lon: 90.5000),
      'নারায়ণগঞ্জ': (lat: 23.6238, lon: 90.5000),
      'comilla': (lat: 23.4607, lon: 91.1809),
      'কুমিল্লা': (lat: 23.4607, lon: 91.1809),
    };
    final key = district.trim().toLowerCase();
    return map[key] ?? const (lat: 23.8103, lon: 90.4125); // Dhaka default
  }

  Future<WeatherSnapshot> fetch(String district) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
    final c = coordsFor(district);

    return _fetchByCoords(
      lat: c.lat,
      lon: c.lon,
      fallbackName: district,
      apiKey: apiKey,
    );
  }

  /// Fetch weather for an arbitrary (lat, lon). Used when the user grants GPS
  /// permission and we want the observation for their actual position.
  Future<WeatherSnapshot> fetchByLatLon({
    required double lat,
    required double lon,
  }) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
    return _fetchByCoords(
      lat: lat,
      lon: lon,
      fallbackName: 'বর্তমান অবস্থান',
      apiKey: apiKey,
    );
  }

  Future<WeatherSnapshot> _fetchByCoords({
    required double lat,
    required double lon,
    required String fallbackName,
    required String apiKey,
  }) async {
    // 1. Current weather.
    final currentUri = Uri.parse(
      '$_base/data/2.5/weather'
      '?lat=$lat&lon=$lon'
      '&units=metric&lang=bn&appid=$apiKey',
    );
    final currentResp = await _client
        .get(currentUri)
        .timeout(const Duration(seconds: 12));
    if (currentResp.statusCode != 200) {
      throw WeatherApiException(
        'current-weather failed (${currentResp.statusCode})',
      );
    }
    final currentJson = jsonDecode(currentResp.body) as Map<String, dynamic>;

    // 2. 5-day / 3-hour forecast — used to synthesize hourly + 7-day buckets.
    final forecastUri = Uri.parse(
      '$_base/data/2.5/forecast'
      '?lat=$lat&lon=$lon'
      '&units=metric&lang=bn&appid=$apiKey',
    );
    final forecastResp = await _client
        .get(forecastUri)
        .timeout(const Duration(seconds: 12));
    if (forecastResp.statusCode != 200) {
      throw WeatherApiException('forecast failed (${forecastResp.statusCode})');
    }
    final forecastJson = jsonDecode(forecastResp.body) as Map<String, dynamic>;

    return _toSnapshot(fallbackName, currentJson, forecastJson);
  }

  WeatherSnapshot _toSnapshot(
    String district,
    Map<String, dynamic> current,
    Map<String, dynamic> forecast,
  ) {
    final main = current['main'] as Map<String, dynamic>? ?? const {};
    final wind = current['wind'] as Map<String, dynamic>? ?? const {};
    final weather0 = ((current['weather'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final cond = _conditionFromOwm(weather0.isNotEmpty ? weather0.first : null);
    final tempC = (main['temp'] as num?)?.toDouble() ?? 0;
    final humidity = ((main['humidity'] as num?)?.toDouble() ?? 0) / 100.0;
    final windKmh = ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6;
    final rainProb = _rainProbFromForecast(forecast, hoursAhead: 6);

    final location = (current['name'] as String?) ?? district;
    final updatedAt = DateTime.now();

    // Hourly = next 8 buckets from forecast (or 1-step synthetic if missing).
    final list =
        ((forecast['list'] as List?) ?? const []).cast<Map>()
            as List<Map<String, dynamic>>;
    final hourly = <HourlyForecast>[];
    for (var i = 0; i < list.length && hourly.length < 8; i++) {
      final entry = list[i];
      hourly.add(
        HourlyForecast(
          time: DateTime.parse(entry['dt_txt'] as String),
          tempC: (entry['main'] as Map?)?['temp'] is num
              ? ((entry['main'])['temp'] as num).toDouble()
              : tempC,
          condition: _conditionFromOwm(_firstWeatherMap(entry)),
          rainProbability: (((entry['pop'] as num?)?.toDouble() ?? 0).clamp(
            0.0,
            1.0,
          )),
          humidity:
              (((entry['main'] as Map?)?['humidity'] as num?)?.toDouble() ??
                  0) /
              100.0,
        ),
      );
    }
    if (hourly.isEmpty) {
      hourly.add(
        HourlyForecast(
          time: updatedAt,
          tempC: tempC,
          condition: cond,
          rainProbability: rainProb,
          humidity: humidity,
        ),
      );
    }

    // Daily — group 3-hour buckets into 7 days (today + next 6).
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final entry in list) {
      final dayKey = (entry['dt_txt'] as String).substring(0, 10);
      byDay.putIfAbsent(dayKey, () => []).add(entry);
    }
    final daily = <DailyForecast>[];
    final sortedDays = byDay.keys.toList()..sort();
    for (final dayKey in sortedDays.take(7)) {
      final entries = byDay[dayKey]!;
      final temps = entries
          .map(
            (e) => ((e['main'] as Map?)?['temp'] as num?)?.toDouble() ?? tempC,
          )
          .toList();
      final maxT = temps.reduce((a, b) => a > b ? a : b);
      final minT = temps.reduce((a, b) => a < b ? a : b);
      final pop = entries
          .map((e) => ((e['pop'] as num?)?.toDouble() ?? 0))
          .fold<double>(0, (a, b) => a > b ? a : b);
      final humidities = entries
          .map(
            (e) => ((e['main'] as Map?)?['humidity'] as num?)?.toDouble() ?? 0,
          )
          .toList();
      final avgHumidity = humidities.isEmpty
          ? humidity
          : (humidities.reduce((a, b) => a + b) / humidities.length) / 100.0;
      // pick midday entry (12:00) if available for the condition icon
      var representative = entries.first;
      for (final e in entries) {
        if ((e['dt_txt'] as String).contains('12:00:00')) {
          representative = e;
          break;
        }
      }
      final dayWind =
          entries
              .map(
                (e) => ((e['wind'] as Map?)?['speed'] as num?)?.toDouble() ?? 0,
              )
              .fold<double>(0, (a, b) => a > b ? a : b) *
          3.6;
      daily.add(
        DailyForecast(
          date: DateTime.parse('${dayKey}T12:00:00'),
          maxTempC: maxT,
          minTempC: minT,
          condition: _conditionFromOwm(_firstWeatherMap(representative)),
          rainProbability: pop.clamp(0.0, 1.0),
          humidity: avgHumidity,
          windKmh: dayWind,
        ),
      );
    }
    if (daily.isEmpty) {
      daily.add(
        DailyForecast(
          date: DateTime.now(),
          maxTempC: tempC,
          minTempC: tempC,
          condition: cond,
          rainProbability: rainProb,
          humidity: humidity,
          windKmh: windKmh,
        ),
      );
    }

    return WeatherSnapshot(
      location: location,
      currentTempC: tempC,
      condition: cond,
      rainProbability: rainProb,
      humidity: humidity,
      windKmh: windKmh,
      updatedAt: updatedAt,
      hourly: hourly,
      daily: daily,
      agronomyAdvice: _agronomyAdvice(
        cond: cond,
        rainProb: rainProb,
        tempC: tempC,
        windKmh: windKmh,
      ),
    );
  }

  // --- helpers --------------------------------------------------------------

  double _rainProbFromForecast(
    Map<String, dynamic> forecast, {
    int hoursAhead = 6,
  }) {
    final list =
        ((forecast['list'] as List?) ?? const []).cast<Map>()
            as List<Map<String, dynamic>>;
    final slice = list.take(hoursAhead ~/ 3 + 1);
    if (slice.isEmpty) return 0.0;
    final pops = slice
        .map((e) => ((e['pop'] as num?)?.toDouble() ?? 0))
        .toList();
    final max = pops.reduce((a, b) => a > b ? a : b);
    return max.clamp(0.0, 1.0);
  }

  WeatherCondition _conditionFromOwm(Map? weather) {
    if (weather == null) return WeatherCondition.partlyCloudy;
    final main = (weather['main'] as String? ?? '').toLowerCase();
    final id = (weather['id'] as num?)?.toInt() ?? 800;
    if (main == 'thunderstorm' || id < 300) return WeatherCondition.stormy;
    if (main == 'drizzle' || main == 'rain' || (id >= 300 && id < 600)) {
      return WeatherCondition.rainy;
    }
    if (main == 'snow') return WeatherCondition.cloudy;
    if (main == 'mist' || main == 'fog' || main == 'haze' || main == 'smoke') {
      return WeatherCondition.foggy;
    }
    if (main == 'clear') return WeatherCondition.sunny;
    if (main == 'clouds') {
      // 801 = few, 802 = scattered, 803-804 = broken/overcast
      if (id == 801 || id == 802) return WeatherCondition.partlyCloudy;
      return WeatherCondition.cloudy;
    }
    return WeatherCondition.partlyCloudy;
  }

  Map<String, dynamic>? _firstWeatherMap(Map<String, dynamic> entry) {
    final w = ((entry['weather'] as List?) ?? const []).cast<Map>().firstOrNull;
    if (w == null) return null;
    return Map<String, dynamic>.from(w);
  }

  String _agronomyAdvice({
    required WeatherCondition cond,
    required double rainProb,
    required double tempC,
    required double windKmh,
  }) {
    final bn = cond.bangla;
    if (rainProb >= 0.7) {
      return 'আজ বৃষ্টির সম্ভাবনা ${(rainProb * 100).round()}%। সেচ স্থগিত রাখুন।';
    }
    if (tempC >= 34) {
      return 'তাপমাত্রা ${tempC.round()}°C — বিকেলে সেচ দিন, দুপুরে এড়িয়ে চলুন।';
    }
    if (windKmh >= 25) {
      return 'ঝড়ো হাওয়া ${windKmh.round()} km/h — কীটনাশক স্প্রে স্থগিত রাখুন।';
    }
    if (cond == WeatherCondition.partlyCloudy ||
        cond == WeatherCondition.sunny) {
      return 'আবহাওয়া $bn — সকালে সেচ ও পরিচর্যার উপযুক্ত সময়।';
    }
    return 'আজকের আবহাওয়া $bn — স্বাভাবিক কৃষি কাজ চালিয়ে যান।';
  }

  void close() => _client.close();
}

class WeatherApiException implements Exception {
  WeatherApiException(this.message);
  final String message;
  @override
  String toString() => 'WeatherApiException: $message';
}
