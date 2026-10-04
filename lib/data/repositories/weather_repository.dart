import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../mock/demo_data.dart';
import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/open_meteo_api.dart';
import '../services/osm_service.dart';
import '../services/weather_api.dart';
import 'local_store.dart';

/// Provides weather snapshots for the home dashboard, weather screen and
/// agronomy advice cards.
///
/// Behaviour (live path):
///   1. Resolve the user's actual coordinates — either live GPS (if granted)
///      or the resolved lat/lon for the farmer's saved district.
///   2. Fetch current + 7-day forecast from Open-Meteo (free, no API key).
///   3. Reverse-geocode the coordinates via OpenStreetMap to label the
///      snapshot with a human-readable locality name.
///   4. If anything in the chain fails, surface the error so the UI renders
///      an ErrorStateView instead of silently substituting bundled demo
///      data. The user can still opt-in to demo via "ডেমো দেখান" on the
///      weather screen.
class WeatherRepository {
  WeatherRepository({
    LocalStore? store,
    WeatherApi? api,
    LocationService? location,
    OsmService? osm,
    OpenMeteoApi? openMeteo,
  })
    // ignore: prefer_initializing_formals
    : _store = store,
       _api = api ?? WeatherApi(),
       _location = location ?? LocationService(),
       _osm = osm ?? OsmService(),
       _openMeteo = openMeteo ?? OpenMeteoApi();

  final LocalStore? _store;
  final WeatherApi _api; // legacy OpenWeatherMap path (kept for fallback)
  final LocationService _location;
  final OsmService _osm;
  final OpenMeteoApi _openMeteo;

  /// True when the latest snapshot came from the bundled demo data
  /// (no live API call). UI can use this to show a disclaimer banner.
  WeatherSnapshot? _lastSnapshot;
  bool _lastWasDemo = true;

  bool get isLastDemo => _lastWasDemo;
  WeatherSnapshot? get lastSnapshot => _lastSnapshot;

  /// Public entrypoint used by `weatherProvider`. Tries live GPS first
  /// and falls back to the farmer's district coords when GPS is denied.
  Future<WeatherSnapshot> current(String district) async {
    final coords = await _location.currentLatLon();
    if (coords != null) {
      String label = district;
      try {
        final rev = await _osm.reverse(lat: coords.lat, lon: coords.lon);
        if (rev != null && rev.trim().isNotEmpty) label = rev;
      } catch (e, st) {
        debugPrint('[WeatherRepository] OSM reverse failed: $e\n$st');
      }
      return _fetchLive(coords.lat, coords.lon, label: label);
    }
    debugPrint(
      '[WeatherRepository] no GPS fix; using district coords for ($district).',
    );
    final c = _coordsForDistrict(district);
    return _fetchLive(c.lat, c.lon, label: district);
  }

  /// Returns a real-time weather snapshot from bundled demo data. This is
  /// a *fallback* path — callers should normally use [current] /
  /// [currentFromGps]; this exists so the UI can render a clearly-marked
  /// demo card instead of raw Khulna hard-coded numbers.
  WeatherSnapshot demoFallback(String district) {
    final demo = DemoData.demoWeather();
    // For the demo snapshot we honour the district name so the UI doesn't
    // look like it lies about location.
    final districtAware = district.trim().isEmpty
        ? demo
        : WeatherSnapshot(
            location: district,
            currentTempC: demo.currentTempC,
            condition: demo.condition,
            rainProbability: demo.rainProbability,
            humidity: demo.humidity,
            windKmh: demo.windKmh,
            updatedAt: demo.updatedAt,
            hourly: demo.hourly,
            daily: demo.daily,
            agronomyAdvice: demo.agronomyAdvice,
          );
    _lastSnapshot = districtAware;
    _lastWasDemo = true;
    return districtAware;
  }

  /// Fetch weather using the device's live GPS coordinates (auto requests
  /// permission) and reverse-geocode via OpenStreetMap for the location
  /// label. If GPS is denied / unavailable the call falls back to
  /// [current] for `fallbackDistrict`. This is the one-shot call used by
  /// `weatherProvider` so the home dashboard always shows *real* weather
  /// for wherever the user actually is.
  Future<WeatherSnapshot> currentFromGps({
    String fallbackDistrict = 'ঢাকা',
  }) async {
    final coords = await _location.currentLatLon();
    if (coords != null) {
      String label = fallbackDistrict;
      try {
        final rev = await _osm.reverse(
          lat: coords.lat,
          lon: coords.lon,
        );
        if (rev != null && rev.trim().isNotEmpty) label = rev;
      } catch (e, st) {
        // reverse-geocode failures must never block the weather fetch.
        debugPrint('[WeatherRepository] OSM reverse failed: $e\n$st');
      }
      return _fetchLive(
        coords.lat,
        coords.lon,
        label: label,
        fallbackDistrict: fallbackDistrict,
      );
    }
    debugPrint(
      '[WeatherRepository] no GPS fix; using district '
      'fallback ($fallbackDistrict).',
    );
    return current(fallbackDistrict);
  }

  /// Refresh using the user's live GPS, then reverse-geocode via OpenStreetMap
  /// so the displayed location name matches the actual coordinates.
  /// Returns the resolved `(lat, lon, label)` or `null` if GPS is unavailable.
  Future<({double lat, double lon, String label})?> refreshFromGps() async {
    final coords = await _location.currentLatLon();
    if (coords == null) return null;
    final label = await _osm.reverse(lat: coords.lat, lon: coords.lon);
    return (
      lat: coords.lat,
      lon: coords.lon,
      label: label ?? 'বর্তমান অবস্থান',
    );
  }

  /// Free-text search via OpenStreetMap.
  /// Returns `(lat, lon, label)` for the best match or `null` if nothing found.
  Future<({double lat, double lon, String label})?> searchLocation(
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    return _osm.search(q);
  }

  /// Fetch weather for an explicit `(lat, lon)` resolved by the caller.
  /// Falls back to district on failure.
  Future<WeatherSnapshot> currentForCoords({
    required double lat,
    required double lon,
    String? label,
    String fallbackDistrict = 'ঢাকা',
  }) async {
    try {
      return await _fetchLive(lat, lon, label: label);
    } catch (e, st) {
      debugPrint(
        '[WeatherRepository] live fetch failed '
        '($lat,$lon -> ${label ?? fallbackDistrict}): $e\n$st',
      );
      rethrow;
    }
  }

  /// Live fetch — prefers Open-Meteo, falls back to OpenWeatherMap when a
  /// key is configured and Open-Meteo is unreachable. Never silently
  /// substitutes demo data.
  Future<WeatherSnapshot> _fetchLive(
    double lat,
    double lon, {
    String? label,
    String fallbackDistrict = 'ঢাকা',
  }) async {
    // 1. Open-Meteo (free, no key)
    try {
      final snap = await _openMeteo.fetchByLatLon(
        lat: lat,
        lon: lon,
        label: label ?? fallbackDistrict,
      );
      _lastSnapshot = snap;
      _lastWasDemo = false;
      _cache(snap);
      return snap;
    } catch (e, st) {
      debugPrint(
        '[WeatherRepository] Open-Meteo fetch failed ($lat,$lon): $e\n$st',
      );
      // 2. Legacy OpenWeatherMap fallback (only when a key is present)
      if (_api.hasKey) {
        try {
          final snap = await _api.fetchByLatLon(lat: lat, lon: lon);
          _lastSnapshot = snap;
          _lastWasDemo = false;
          _cache(snap);
          return snap;
        } catch (e2, st2) {
          debugPrint(
            '[WeatherRepository] OpenWeatherMap fallback failed: $e2\n$st2',
          );
        }
      }
      throw WeatherLiveDataUnavailable(
        'Live weather fetch failed for ($lat, $lon).',
        cause: e is Exception ? e : null,
      );
    }
  }

  /// Hard-coded coordinates for the districts we support, used when the
  /// user denies GPS. Mirrors the map the legacy OWM path used to own.
  ({double lat, double lon}) _coordsForDistrict(String district) {
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

  void _cache(WeatherSnapshot snap) {
    final store = _store;
    if (store == null) return;
    final payload = {
      'location': snap.location,
      'currentTempC': snap.currentTempC,
      'condition': snap.condition.name,
      'rainProbability': snap.rainProbability,
      'humidity': snap.humidity,
      'windKmh': snap.windKmh,
      'updatedAt': snap.updatedAt.toIso8601String(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    try {
      store.writeJson(_cacheKey, payload);
    } catch (e, st) {
      debugPrint('[WeatherRepository] local _cache failed: $e\n$st');
    }
    // Best-effort mirror to Firestore so a fresh install still has the last
    // known snapshot without waiting on a live API call.
    final phone = store.phoneKey;
    if (phone == null) return;
    try {
      FsPaths.weatherCache(phone).set(payload);
    } catch (e, st) {
      debugPrint('[WeatherRepository] remote _cache failed: $e\n$st');
    }
  }

  static const String _cacheKey = 'weather_cache_v1';
}

/// Thrown when live weather cannot be retrieved (no API key, network
/// failure, 401 from OpenWeatherMap, etc). The UI should display this as
/// an error state and never substitute bundled demo data without
/// explicit user consent.
class WeatherLiveDataUnavailable implements Exception {
  WeatherLiveDataUnavailable(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'WeatherLiveDataUnavailable: $message'
      '${cause != null ? ' ($cause)' : ''}';
}
