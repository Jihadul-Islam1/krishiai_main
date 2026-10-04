import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around `geolocator` so the rest of the app can request a
/// one-shot GPS fix without depending on the plugin directly.
///
/// Behaviour:
/// 1. On platforms where `geolocator` is not registered (Windows desktop,
///    some web shells) → return `null` immediately so callers can fall
///    back to the OWM district lookup instead of seeing a
///    `MissingPluginException`.
/// 2. If location service is off → return `null`.
/// 3. If we have no permission → request it once; if still denied → `null`.
/// 4. Otherwise return `Position` with the current lat/lon.
///
/// All error paths are logged via `debugPrint` so the previous silent
/// fall-through to demo data is no longer invisible.
class LocationService {
  LocationService({Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 12);

  final Duration _timeout;

  /// Platforms where `geolocator` actually implements
  /// `getCurrentPosition`. Windows desktop in particular throws
  /// `MissingPluginException` because the package ships no Windows
  /// implementation.
  bool get _isPlatformSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<bool> _ensureServiceOn() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<Position?> currentPosition() async {
    if (!_isPlatformSupported) {
      debugPrint(
        '[LocationService] geolocator not registered for '
        '${kIsWeb ? "web" : defaultTargetPlatform.name}; '
        'skipping GPS and falling back to district lookup.',
      );
      return null;
    }
    try {
      if (!await _ensureServiceOn()) {
        debugPrint('[LocationService] location service disabled.');
        return null;
      }
      if (!await _ensurePermission()) {
        debugPrint('[LocationService] location permission denied.');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeout,
        ),
      );
    } catch (e, st) {
      debugPrint('[LocationService] getCurrentPosition failed: $e\n$st');
      return null;
    }
  }

  /// Resolve `(lat, lon)` or `null` if GPS is unavailable/denied.
  Future<({double lat, double lon})?> currentLatLon() async {
    final pos = await currentPosition();
    if (pos == null) return null;
    return (lat: pos.latitude, lon: pos.longitude);
  }
}