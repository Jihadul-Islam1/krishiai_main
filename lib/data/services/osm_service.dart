import 'dart:convert';
import 'package:http/http.dart' as http;

/// OpenStreetMap helpers. We use:
///  * `reverse?lat&lon`  — convert a GPS fix into a human-readable address
///  * `search?q=...`     — free-text search → best-matching `(lat, lon, label)`
///
/// All endpoints are public (no API key) but require a descriptive
/// `User-Agent` per OSM's tile-server policy — we set it on every call.
class OsmService {
  OsmService({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'KrishiAi/1.0 (flutter app)',
    'Accept-Language': 'bn,en',
  };

  final http.Client _client;

  /// Reverse-geocode `(lat, lon)` to a short Bangla-fallback address.
  /// Returns `null` on any failure (network, no internet, rate-limit).
  Future<String?> reverse({required double lat, required double lon}) async {
    try {
      final uri = Uri.parse('$_base/reverse').replace(
        queryParameters: <String, String>{
          'format': 'jsonv2',
          'lat': lat.toString(),
          'lon': lon.toString(),
          'zoom': '14',
          'addressdetails': '1',
        },
      );
      final resp = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return _prettyLabel(body);
    } catch (_) {
      return null;
    }
  }

  /// Free-text search. Returns the best match or `null` if nothing found.
  Future<({double lat, double lon, String label})?> search(String query) async {
    try {
      final uri = Uri.parse('$_base/search').replace(queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
      });
      final resp = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (resp.statusCode != 200) return null;
      final list = jsonDecode(resp.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.parse(first['lat'] as String);
      final lon = double.parse(first['lon'] as String);
      return (lat: lat, lon: lon, label: _prettyLabel(first) ?? query);
    } catch (_) {
      return null;
    }
  }

  /// Pick a concise label from a Nominatim response. Bangla when available,
  /// otherwise English. Falls back to the raw `display_name`.
  String? _prettyLabel(Map<String, dynamic> body) {
    final addr = body['address'] as Map<String, dynamic>?;
    if (addr != null) {
      final city =
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
      final state = addr['state'];
      final country = addr['country'];
      final parts = <String>[
        if (city != null) city.toString(),
        if (state != null) state.toString(),
        if (country != null) country.toString(),
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final disp = body['display_name'] as String?;
    return (disp == null || disp.isEmpty) ? null : disp;
  }
}