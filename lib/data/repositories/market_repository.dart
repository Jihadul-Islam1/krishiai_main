import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/services/fs_paths.dart';
import '../models/market_price.dart';
import 'local_store.dart';

/// Live market prices with DAM API best-effort + LocalStore cache +
/// district-aware bundled fallback + favorites + 14-day rolling history.
class MarketRepository {
  MarketRepository({LocalStore? store, http.Client? client})
      // ignore: prefer_initializing_formals - we need the null-fallback.
      : _store = store,
        _client = client ?? http.Client();

  static const _cacheKey = 'market_cache_v2';
  static const _favKey = 'market_favorites_v1';
  static const _cacheTtl = Duration(hours: 6);
  static const _apiBase = 'https://www.dam.gov.bd/api/v1/price';

  final LocalStore? _store;
  final http.Client _client;

  /// Public entry point — returns all live prices for [location] (district).
  /// Strategy: cache → Firestore global catalog (real curated data) →
  /// DAM API → district-aware bundled fallback.
  Future<List<MarketPrice>> all(String location) async {
    final district = _normalizeDistrict(location);
    final cached = await _readCache(district);
    if (cached != null && cached.isNotEmpty) {
      return _applyFavorites(cached);
    }
    final live = await _fetchFirestoreLive(district);
    if (live != null && live.isNotEmpty) {
      await _persistCache(district, live);
      return _applyFavorites(live);
    }
    final dam = await _fetchDam(district);
    if (dam != null && dam.isNotEmpty) {
      await _persistCache(district, dam);
      return _applyFavorites(dam);
    }
    final bundled = _bundled(district);
    await _persistCache(district, bundled);
    return _applyFavorites(bundled);
  }

  /// Streams curated prices from the global `market_prices_live` collection,
  /// merged with the bundled fallback catalog by id. Falls back to a
  /// single-shot `all()` when Firestore is unavailable so the UI never blocks.
  Stream<List<MarketPrice>> watch(String location) async* {
    final district = _normalizeDistrict(location);
    try {
      await for (final snap in FsPaths.marketPricesLive().snapshots()) {
        final live = _parseFirestoreLive(snap.docs, district);
        yield _applyFavorites(_mergeWithBundled(live, district));
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MarketRepository] watch failed: $e\n$st');
      }
      // Firestore unreachable: fall back to the cached / bundled path so the
      // UI never hangs on a loading state.
      yield await all(district);
    }
  }

  Future<List<MarketPrice>> favorites(String location) async {
    final list = await all(location);
    return list.where((m) => m.isFavorite).toList(growable: false);
  }

  Future<MarketPrice?> byId(String id, String location) async {
    final list = await all(location);
    for (final m in list) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<List<MarketPrice>> search(String query, String location) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all(location);
    final list = await all(location);
    return list.where((m) =>
      m.cropName.toLowerCase().contains(q) ||
      m.category.toLowerCase().contains(q)
    ).toList(growable: false);
  }

  Future<List<MarketPrice>> byCategory(String category, String location) async {
    final list = await all(location);
    return list.where((m) => m.category == category).toList(growable: false);
  }

  Future<List<String>> categories(String location) async {
    final list = await all(location);
    final set = <String>{};
    for (final m in list) {
      set.add(m.category);
    }
    final out = set.toList()..sort();
    return out;
  }

  Future<MarketPrice> toggleFavorite(MarketPrice m) async {
    final updated = m.copyWith(isFavorite: !m.isFavorite);
    final store = _store;
    if (store == null) return updated;
    final raw = store.readJson(_favKey);
    final list = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    final set = list.toSet();
    if (updated.isFavorite) {
      set.add(updated.id);
    } else {
      set.remove(updated.id);
    }
    await store.writeJson(_favKey, set.toList());

    // Mirror favorites to Firestore so they survive a reinstall.
    final phone = store.phoneKey;
    if (phone != null) {
      try {
        await FsPaths.userDoc(phone)
            .collection('market_favorites')
            .doc(updated.id)
            .set({'favoritedAt': DateTime.now().toIso8601String()});
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[MarketRepository] favorite sync failed: $e\n$st');
        }
      }
    }
    return updated;
  }

  String marketForDistrict(String location) {
    final d = _normalizeDistrict(location);
    return _marketForDistrict[d] ?? 'সদর বাজার';
  }

  Future<void> dispose() async {
    _client.close();
  }

  // ---------------------------------------------------------------------------
  // DAM API best-effort fetch.
  // ---------------------------------------------------------------------------
  Future<List<MarketPrice>?> _fetchDam(String district) async {
    try {
      final uri = Uri.parse(
        '$_apiBase?district=${Uri.encodeQueryComponent(district)}&lang=bn',
      );
      final resp = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      final list = (decoded is Map<String, dynamic> && decoded['data'] is List)
          ? decoded['data'] as List<dynamic>
          : (decoded is List ? decoded : null);
      if (list == null || list.isEmpty) return null;
      final out = <MarketPrice>[];
      for (final raw in list) {
        final m = _parseDamEntry(raw, district);
        if (m != null) out.add(m);
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  MarketPrice? _parseDamEntry(dynamic raw, String district) {
    try {
      final m = raw as Map<String, dynamic>;
      final name = (m['commodity'] ?? m['name'] ?? '').toString().trim();
      if (name.isEmpty) return null;
      final unit = (m['unit'] ?? 'কেজি').toString();
      final price = double.tryParse(
            (m['price'] ?? m['retail'] ?? '').toString(),
          ) ??
          0;
      if (price <= 0) return null;
      final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final category = (m['category'] ?? 'সবজি').toString();
      final bias = _districtBias[district] ?? 1.0;
      final base = (price * bias).roundToDouble();
      final prev = (base * (1 - (math.Random().nextDouble() - 0.5) * 0.04))
          .roundToDouble();
      return MarketPrice(
        id: id,
        cropName: name,
        market: marketForDistrict(district),
        unit: unit,
        currentPrice: base,
        previousPrice: prev,
        updatedAt: DateTime.now(),
        source: 'DAM',
        history: _attachHistory(base, id),
        category: category,
        minPrice: _minOf(base),
        maxPrice: _maxOf(base),
      );
    } catch (_) {
      return null;
    }
  }

  double _minOf(double current) {
    final r = math.Random(current.toInt() ^ 0xA1B2);
    return (current * (0.92 + r.nextDouble() * 0.03)).roundToDouble();
  }

  double _maxOf(double current) {
    final r = math.Random(current.toInt() ^ 0xC3D4);
    return (current * (1.02 + r.nextDouble() * 0.05)).roundToDouble();
  }

  // ---------------------------------------------------------------------------
  // Firestore global catalog (`market_prices_live`). Each doc id is a crop id
  // (e.g. `potato`, `rice_miniket`) and contains the latest curated DAM-sourced
  // entry for that crop. Per-district bias is applied so the displayed price
  // reflects the user's local market, mirroring the DAM API path.
  // ---------------------------------------------------------------------------
  Future<List<MarketPrice>?> _fetchFirestoreLive(String district) async {
    try {
      final snap = await FsPaths.marketPricesLive()
          .limit(500)
          .get(const GetOptions(source: Source.server));
      if (snap.docs.isEmpty) return null;
      return _mergeWithBundled(_parseFirestoreLive(snap.docs, district), district);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MarketRepository] firestore live fetch failed: $e\n$st');
      }
      return null;
    }
  }

  /// Picks the newest entry per crop id from a Firestore snapshot and applies
  /// district bias + min/max bands so the rendered MarketPrice matches the
  /// shape produced by the DAM / bundled paths.
  List<MarketPrice> _parseFirestoreLive(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String district,
  ) {
    final byId = <String, MarketPrice>{};
    for (final doc in docs) {
      final data = doc.data();
      final id = (data['id'] ?? doc.id).toString();
      final name = (data['cropName'] ?? data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final raw = (data['currentPrice'] as num?)?.toDouble() ?? 0;
      if (raw <= 0) continue;
      final bias = _districtBias[district] ?? 1.0;
      final current = (raw * bias).roundToDouble();
      final previous = (data['previousPrice'] as num?)?.toDouble() ??
          (current * (1 + (math.Random(id.hashCode).nextDouble() - 0.5) * 0.03))
              .roundToDouble();
      final updatedRaw = data['updatedAt'];
      DateTime updatedAt;
      if (updatedRaw is Timestamp) {
        updatedAt = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        updatedAt = DateTime.tryParse(updatedRaw) ?? DateTime.now();
      } else {
        updatedAt = DateTime.now();
      }
      final existing = byId[id];
      if (existing != null && !updatedAt.isAfter(existing.updatedAt)) {
        continue;
      }
      final unit = (data['unit'] ?? 'কেজি').toString();
      final category = (data['category'] ?? 'সবজি').toString();
      final market = (data['market'] as String?)?.trim().isNotEmpty == true
          ? data['market'] as String
          : marketForDistrict(district);
      final minP = (data['minPrice'] as num?)?.toDouble() ?? _minOf(current);
      final maxP = (data['maxPrice'] as num?)?.toDouble() ?? _maxOf(current);
      byId[id] = MarketPrice(
        id: id,
        cropName: name,
        market: market,
        unit: unit,
        currentPrice: current,
        previousPrice: previous,
        updatedAt: updatedAt,
        source: 'Firestore',
        history: _attachHistory(current, id),
        category: category,
        minPrice: minP,
        maxPrice: maxP,
      );
    }
    return byId.values.toList(growable: false);
  }

  /// Merges Firestore live entries over the bundled catalog by id so the UI
  /// always has a full catalog to render (any crop the admin hasn't pushed
  /// yet still shows up from the bundled fallback).
  List<MarketPrice> _mergeWithBundled(
    List<MarketPrice> live,
    String district,
  ) {
    if (live.isEmpty) return _bundled(district);
    final merged = <String, MarketPrice>{for (final m in live) m.id: m};
    for (final m in _bundled(district)) {
      merged.putIfAbsent(m.id, () => m);
    }
    return merged.values.toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Cache layer.
  // ---------------------------------------------------------------------------
  Future<void> _persistCache(String district, List<MarketPrice> items) async {
    final store = _store;
    if (store == null) return;
    final raw = store.readJson(_cacheKey);
    final map = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final entry = {
      'savedAt': DateTime.now().toIso8601String(),
      'items': items.map((m) => m.toJson()).toList(),
    };
    map[district] = entry;
    await store.writeJson(_cacheKey, map);

    // Mirror the latest cache snapshot to Firestore so a fresh install still
    // sees last-known prices while DAM is re-contacted in the background.
    final phone = store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.marketCache(phone).set({
        'updatedAt': DateTime.now().toIso8601String(),
        'byDistrict': {district: entry},
      }, SetOptions(merge: true));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MarketRepository] cache sync failed: $e\n$st');
      }
    }
  }

  Future<List<MarketPrice>?> _readCache(String district) async {
    final store = _store;
    if (store == null) return null;
    final raw = store.readJson(_cacheKey);
    if (raw is! Map<String, dynamic>) return null;
    final entry = raw[district];
    if (entry is! Map<String, dynamic>) return null;
    final savedAt = entry['savedAt'] as String?;
    final items = entry['items'] as List<dynamic>?;
    if (savedAt == null || items == null) return null;
    final age = DateTime.now().difference(DateTime.parse(savedAt));
    if (age > _cacheTtl) return null;
    return items
        .whereType<Map<String, dynamic>>()
        .map(MarketPrice.fromJson)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // District-aware bundled catalog (used when DAM is unreachable and no cache).
  // ---------------------------------------------------------------------------
  List<MarketPrice> _bundled(String district) {
    final bias = _districtBias[district] ?? 1.0;
    final market = marketForDistrict(district);
    final now = DateTime.now();
    final list = <MarketPrice>[];
    for (final entry in _bundledCatalog) {
      final id = entry['id'] as String;
      final bn = entry['bn'] as String;
      final en = entry['en'] as String;
      final unit = entry['unit'] as String;
      final category = entry['category'] as String;
      final base = (entry['base'] as num).toDouble() * bias;
      final rnd = math.Random(('$id|$en|$district').hashCode);
      final current = (base * (1 + (rnd.nextDouble() - 0.5) * 0.05))
          .roundToDouble();
      final previous = (base * (1 + (rnd.nextDouble() - 0.5) * 0.05))
          .roundToDouble();
      final minP = (current * 0.93).roundToDouble();
      final maxP = (current * 1.07).roundToDouble();
      list.add(MarketPrice(
        id: id,
        cropName: bn,
        market: market,
        unit: unit,
        currentPrice: current,
        previousPrice: previous,
        updatedAt: now,
        source: 'Bundled',
        history: _attachHistory(current, id),
        category: category,
        minPrice: minP,
        maxPrice: maxP,
      ));
    }
    return list;
  }

  List<PricePoint> _attachHistory(double base, String seed) {
    final rand = math.Random(seed.hashCode);
    final now = DateTime.now();
    final out = <PricePoint>[];
    double price = base;
    for (int i = 13; i >= 0; i--) {
      final delta = (rand.nextDouble() - 0.5) * 0.06;
      price = (price * (1 + delta))
          .clamp(base * 0.85, base * 1.15)
          .toDouble();
      out.add(PricePoint(
        date: now.subtract(Duration(days: i)),
        price: price,
      ));
    }
    return out;
  }

  List<MarketPrice> _applyFavorites(List<MarketPrice> items) {
    final store = _store;
    if (store == null) return items;
    final raw = store.readJson(_favKey);
    if (raw is! List) return items;
    final favs = raw.map((e) => e.toString()).toSet();
    if (favs.isEmpty) return items;
    return items
        .map((m) => m.copyWith(isFavorite: favs.contains(m.id)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  String _normalizeDistrict(String location) {
    final d = location.trim();
    if (d.isEmpty) return 'ঢাকা';
    if (_districtBias.containsKey(d)) return d;
    final lower = d.toLowerCase();
    for (final k in _districtBias.keys) {
      if (k.toLowerCase() == lower) return k;
    }
    for (final k in _districtBias.keys) {
      if (lower.contains(k.toLowerCase())) return k;
    }
    for (final k in _districtBias.keys) {
      if (k.toLowerCase().contains(lower)) return k;
    }
    return 'ঢাকা';
  }

  // Per-district multipliers (Dhaka = 1.00).
  static const Map<String, double> _districtBias = <String, double>{
    'ঢাকা': 1.00, 'গাজীপুর': 1.00, 'নারায়ণগঞ্জ': 0.99,
    'চট্টগ্রাম': 1.05, 'কুমিল্লা': 1.02, 'সিলেট': 1.04,
    'খুলনা': 0.97, 'যশোর': 0.96, 'সাতক্ষীরা': 0.95,
    'রাজশাহী': 0.95, 'বগুড়া': 0.94, 'পাবনা': 0.94,
    'রংপুর': 0.93, 'দিনাজপুর': 0.93, 'কুড়িগ্রাম': 0.92,
    'ময়মনসিংহ': 0.97, 'টাঙ্গাইল': 0.98, 'জামালপুর': 0.97,
    'বরিশাল': 0.98, 'পটুয়াখালী': 0.99, 'বরগুনা': 0.98,
    'ফরিদপুর': 0.97, 'গোপালগঞ্জ': 0.97, 'মাদারীপুর': 0.97,
    "কক্সবাজার": 1.06, 'রাঙামাটি': 1.03, 'বান্দরবান': 1.03,
    'খাগড়াছড়ি': 1.02, 'মৌলভীবাজার': 1.03, 'হবিগঞ্জ': 1.03,
    'সুনামগঞ্জ': 1.02, 'নরসিংদী': 0.99, 'কিশোরগঞ্জ': 0.98,
    'মানিকগঞ্জ': 0.99, 'মুন্সীগঞ্জ': 0.99, 'রাজবাড়ী': 0.96,
    'শরীয়তপুর': 0.97, 'চাঁদপুর': 1.00, 'লক্ষ্মীপুর': 1.00,
    'নোয়াখালী': 1.01, 'ফেনী': 1.01, 'ব্রাহ্মণবাড়িয়া': 1.01,
    'চুয়াডাঙা': 0.95, 'মেহেরপুর': 0.95, 'ঝিনাইদহ': 0.96,
    'মাগুরা': 0.96, 'নড়াইল': 0.96, 'বাগেরহাট': 0.96,
    'পিরোজপুর': 0.98, 'ঝালকাঠি': 0.98, 'ভোলা': 0.99,
    'নাটোর': 0.94, 'নওগাঁ': 0.94,
    'চাঁপাইনবাবগঞ্জ': 0.93, 'জয়পুরহাট': 0.94, 'গাইবান্ধা': 0.93,
    'লালমনিরহাট': 0.93, 'নীলফামারী': 0.93, 'ঠাকুরগাঁও': 0.93,
    'পঞ্চগড়': 0.93, 'শেরপুর': 0.96, 'নেত্রকোণা': 0.97,
  };

  static const Map<String, String> _marketForDistrict = <String, String>{
    'ঢাকা': 'কাওরান বাজার',
    'গাজীপুর': 'গাজীপুর বাজার',
    'নারায়ণগঞ্জ': 'নারায়ণগঞ্জ বাজার',
    'চট্টগ্রাম': 'রেয়াজউদ্দিন বাজার',
    'কুমিল্লা': 'কুমিল্লা সদর',
    'সিলেট': 'বন্দর বাজার',
    'খুলনা': 'খলিশপুর',
    'যশোর': 'যশোর সদর',
    'সাতক্ষীরা': 'সাতক্ষীরা সদর',
    'রাজশাহী': 'সাহেব বাজার',
    'বগুড়া': 'বগুড়া সদর',
    'পাবনা': 'পাবনা সদর',
    'রংপুর': 'সিটি মার্কেট',
    'দিনাজপুর': 'দিনাজপুর সদর',
    'কুড়িগ্রাম': 'কুড়িগ্রাম সদর',
    'ময়মনসিংহ': 'নতুন বাজার',
    'টাঙ্গাইল': 'টাঙ্গাইল সদর',
    'জামালপুর': 'জামালপুর সদর',
    'বরিশাল': 'সদর রোড',
    'পটুয়াখালী': 'পটুয়াখালী সদর',
    'বরগুনা': 'বরগুনা সদর',
    'ফরিদপুর': 'ফরিদপুর সদর',
    'গোপালগঞ্জ': 'গোপালগঞ্জ সদর',
    'মাদারীপুর': 'মাদারীপুর সদর',
    'কক্সবাজার': 'কক্সবাজার সদর',
    'রাঙামাটি': 'রাঙামাটি সদর',
    'বান্দরবান': 'বান্দরবান সদর',
    'খাগড়াছড়ি': 'খাগড়াছড়ি সদর',
    'মৌলভীবাজার': 'মৌলভীবাজার সদর',
    'হবিগঞ্জ': 'হবিগঞ্জ সদর',
    'সুনামগঞ্জ': 'সুনামগঞ্জ সদর',
    'নরসিংদী': 'নরসিংদী সদর',
    'কিশোরগঞ্জ': 'কিশোরগঞ্জ সদর',
    'মানিকগঞ্জ': 'মানিকগঞ্জ সদর',
    'মুন্সীগঞ্জ': 'মুন্সীগঞ্জ সদর',
    'রাজবাড়ী': 'রাজবাড়ী সদর',
    'শরীয়তপুর': 'শরীয়তপুর সদর',
    'চাঁদপুর': 'চাঁদপুর সদর',
    'লক্ষ্মীপুর': 'লক্ষ্মীপুর সদর',
    'নোয়াখালী': 'নোয়াখালী সদর',
    'ফেনী': 'ফেনী সদর',
    'ব্রাহ্মণবাড়িয়া': 'ব্রাহ্মণবাড়িয়া সদর',
    'চুয়াডাঙা': 'চুয়াডাঙা সদর',
    'মেহেরপুর': 'মেহেরপুর সদর',
    'ঝিনাইদহ': 'ঝিনাইদহ সদর',
    'মাগুরা': 'মাগুরা সদর',
    'নড়াইল': 'নড়াইল সদর',
    'বাগেরহাট': 'বাগেরহাট সদর',
    'পিরোজপুর': 'পিরোজপুর সদর',
    'ঝালকাঠি': 'ঝালকাঠি সদর',
    'ভোলা': 'ভোলা সদর',
    'নাটোর': 'নাটোর সদর',
    'নওগাঁ': 'নওগাঁ সদর',
    'চাঁপাইনবাবগঞ্জ': 'চাঁপাইনবাবগঞ্জ সদর',
    'জয়পুরহাট': 'জয়পুরহাট সদর',
    'গাইবান্ধা': 'গাইবান্ধা সদর',
    'লালমনিরহাট': 'লালমনিরহাট সদর',
    'নীলফামারী': 'নীলফামারী সদর',
    'ঠাকুরগাঁও': 'ঠাকুরগাঁও সদর',
    'পঞ্চগড়': 'পঞ্চগড় সদর',
    'শেরপুর': 'শেরপুর সদর',
    'নেত্রকোণা': 'নেত্রকোণা সদর',
  };

  // Bundled crop catalog — Bangla name, English name, base BDT/kg, category.
  static final List<Map<String, dynamic>> _bundledCatalog = <Map<String, dynamic>>[
    {'id': 'rice_miniket', 'bn': 'মিনিকেট চাল', 'en': 'Miniket Rice', 'unit': 'কেজি', 'category': 'চাল', 'base': 65.0},
    {'id': 'rice_nazir', 'bn': 'নাজিরশাইল চাল', 'en': 'Nazirshail Rice', 'unit': 'কেজি', 'category': 'চাল', 'base': 75.0},
    {'id': 'rice_rupali', 'bn': 'রূপালি চাল', 'en': 'Rupali Rice', 'unit': 'কেজি', 'category': 'চাল', 'base': 55.0},
    {'id': 'rice_pajam', 'bn': 'পাজাম চাল', 'en': 'Pajam Rice', 'unit': 'কেজি', 'category': 'চাল', 'base': 60.0},
    {'id': 'rice_gondho', 'bn': 'গন্ধ চাল', 'en': 'Gondho Rice', 'unit': 'কেজি', 'category': 'চাল', 'base': 70.0},
    {'id': 'wheat_local', 'bn': 'স্থানীয় গম', 'en': 'Local Wheat', 'unit': 'কেজি', 'category': 'গম', 'base': 45.0},
    {'id': 'wheat_imported', 'bn': 'আমদানি গম', 'en': 'Imported Wheat', 'unit': 'কেজি', 'category': 'গম', 'base': 50.0},
    {'id': 'potato', 'bn': 'আলু', 'en': 'Potato', 'unit': 'কেজি', 'category': 'সবজি', 'base': 30.0},
    {'id': 'onion', 'bn': 'পেঁয়াজ', 'en': 'Onion', 'unit': 'কেজি', 'category': 'সবজি', 'base': 55.0},
    {'id': 'garlic', 'bn': 'রসুন', 'en': 'Garlic', 'unit': 'কেজি', 'category': 'সবজি', 'base': 120.0},
    {'id': 'ginger', 'bn': 'আদা', 'en': 'Ginger', 'unit': 'কেজি', 'category': 'সবজি', 'base': 140.0},
    {'id': 'tomato', 'bn': 'টমেটো', 'en': 'Tomato', 'unit': 'কেজি', 'category': 'সবজি', 'base': 40.0},
    {'id': 'brinjal', 'bn': 'বেগুন', 'en': 'Brinjal', 'unit': 'কেজি', 'category': 'সবজি', 'base': 35.0},
    {'id': 'ladies_finger', 'bn': 'ঢেঁড়স', 'en': 'Ladies Finger', 'unit': 'কেজি', 'category': 'সবজি', 'base': 30.0},
    {'id': 'ridge_gourd', 'bn': 'ঝিঙে', 'en': 'Ridge Gourd', 'unit': 'কেজি', 'category': 'সবজি', 'base': 35.0},
    {'id': 'bitter_gourd', 'bn': 'করলা', 'en': 'Bitter Gourd', 'unit': 'কেজি', 'category': 'সবজি', 'base': 45.0},
    {'id': 'cucumber', 'bn': 'শসা', 'en': 'Cucumber', 'unit': 'কেজি', 'category': 'সবজি', 'base': 25.0},
    {'id': 'cauliflower', 'bn': 'ফুলকপি', 'en': 'Cauliflower', 'unit': 'কেজি', 'category': 'সবজি', 'base': 30.0},
    {'id': 'cabbage', 'bn': 'বাঁধাকপি', 'en': 'Cabbage', 'unit': 'কেজি', 'category': 'সবজি', 'base': 25.0},
    {'id': 'carrot', 'bn': 'গাজর', 'en': 'Carrot', 'unit': 'কেজি', 'category': 'সবজি', 'base': 50.0},
    {'id': 'radish', 'bn': 'মুলা', 'en': 'Radish', 'unit': 'কেজি', 'category': 'সবজি', 'base': 25.0},
    {'id': 'spinach', 'bn': 'পালংশাক', 'en': 'Spinach', 'unit': 'কেজি', 'category': 'সবজি', 'base': 30.0},
    {'id': 'green_chili', 'bn': 'কাঁচা মরিচ', 'en': 'Green Chili', 'unit': 'কেজি', 'category': 'সবজি', 'base': 80.0},
    {'id': 'red_chili', 'bn': 'শুকনো মরিচ', 'en': 'Dry Chili', 'unit': 'কেজি', 'category': 'মসলা', 'base': 350.0},
    {'id': 'turmeric', 'bn': 'হলুদ', 'en': 'Turmeric', 'unit': 'কেজি', 'category': 'মসলা', 'base': 220.0},
    {'id': 'coriander_seed', 'bn': 'ধনিয়া', 'en': 'Coriander Seed', 'unit': 'কেজি', 'category': 'মসলা', 'base': 110.0},
    {'id': 'cumin', 'bn': 'জিরা', 'en': 'Cumin', 'unit': 'কেজি', 'category': 'মসলা', 'base': 600.0},
    {'id': 'coriander_leaf', 'bn': 'ধনেপাতা', 'en': 'Coriander Leaf', 'unit': 'কেজি', 'category': 'সবজি', 'base': 40.0},
    {'id': 'banana_sabri', 'bn': 'সবরি কলা', 'en': 'Sabri Banana', 'unit': 'ডজন', 'category': 'ফল', 'base': 60.0},
    {'id': 'banana_chaa', 'bn': 'চাঁপা কলা', 'en': 'Champa Banana', 'unit': 'ডজন', 'category': 'ফল', 'base': 50.0},
    {'id': 'mango_himsagar', 'bn': 'হিমসাগর আম', 'en': 'Himsagar Mango', 'unit': 'কেজি', 'category': 'ফল', 'base': 120.0},
    {'id': 'mango_langra', 'bn': 'ল্যাংড়া আম', 'en': 'Langra Mango', 'unit': 'কেজি', 'category': 'ফল', 'base': 100.0},
    {'id': 'mango_amropali', 'bn': 'আম্রপালি আম', 'en': 'Amropali Mango', 'unit': 'কেজি', 'category': 'ফল', 'base': 140.0},
    {'id': 'jackfruit', 'bn': 'কাঁঠাল', 'en': 'Jackfruit', 'unit': 'কেজি', 'category': 'ফল', 'base': 50.0},
    {'id': 'pineapple', 'bn': 'আনারস', 'en': 'Pineapple', 'unit': 'পিস', 'category': 'ফল', 'base': 45.0},
    {'id': 'papaya', 'bn': 'পেঁপে', 'en': 'Papaya', 'unit': 'কেজি', 'category': 'ফল', 'base': 35.0},
    {'id': 'guava', 'bn': 'পেয়ারা', 'en': 'Guava', 'unit': 'কেজি', 'category': 'ফল', 'base': 50.0},
    {'id': 'litchi', 'bn': 'লিচু', 'en': 'Litchi', 'unit': 'কেজি', 'category': 'ফল', 'base': 200.0},
    {'id': 'watermelon', 'bn': 'তরমুজ', 'en': 'Watermelon', 'unit': 'কেজি', 'category': 'ফল', 'base': 35.0},
    {'id': 'jute', 'bn': 'পাট', 'en': 'Jute', 'unit': 'মণ', 'category': 'ফসল', 'base': 3200.0},
    {'id': 'mustard_seed', 'bn': 'সরিষা', 'en': 'Mustard Seed', 'unit': 'কেজি', 'category': 'তেলবীজ', 'base': 80.0},
    {'id': 'sesame', 'bn': 'তিল', 'en': 'Sesame', 'unit': 'কেজি', 'category': 'তেলবীজ', 'base': 180.0},
    {'id': 'soybean', 'bn': 'সয়াবিন', 'en': 'Soybean', 'unit': 'কেজি', 'category': 'তেলবীজ', 'base': 100.0},
    {'id': 'lentil_masoor', 'bn': 'মসুর ডাল', 'en': 'Masoor Lentil', 'unit': 'কেজি', 'category': 'ডাল', 'base': 130.0},
    {'id': 'lentil_mung', 'bn': 'মুগ ডাল', 'en': 'Mung Lentil', 'unit': 'কেজি', 'category': 'ডাল', 'base': 150.0},
    {'id': 'lentil_chola', 'bn': 'ছোলা ডাল', 'en': 'Chickpea', 'unit': 'কেজি', 'category': 'ডাল', 'base': 110.0},
    {'id': 'lentil_khesari', 'bn': 'খেসারি ডাল', 'en': 'Khesari Lentil', 'unit': 'কেজি', 'category': 'ডাল', 'base': 85.0},
    {'id': 'tea', 'bn': 'চা পাতা', 'en': 'Tea Leaf', 'unit': 'কেজি', 'category': 'ফসল', 'base': 220.0},
    {'id': 'sugarcane', 'bn': 'আখ', 'en': 'Sugarcane', 'unit': 'মণ', 'category': 'ফসল', 'base': 380.0},
    {'id': 'cow_milk', 'bn': 'গরুর দুধ', 'en': 'Cow Milk', 'unit': 'লিটার', 'category': 'দুগ্ধ', 'base': 75.0},
    {'id': 'buffalo_milk', 'bn': 'মহিষের দুধ', 'en': 'Buffalo Milk', 'unit': 'লিটার', 'category': 'দুগ্ধ', 'base': 95.0},
    {'id': 'egg_chicken', 'bn': 'মুরগির ডিম', 'en': 'Chicken Egg', 'unit': 'ডজন', 'category': 'প্রাণিজ', 'base': 110.0},
    {'id': 'chicken_broiler', 'bn': 'ব্রয়লার মুরগি', 'en': 'Broiler Chicken', 'unit': 'কেজি', 'category': 'প্রাণিজ', 'base': 180.0},
    {'id': 'fish_rohu', 'bn': 'রুই মাছ', 'en': 'Rohu Fish', 'unit': 'কেজি', 'category': 'মাছ', 'base': 280.0},
    {'id': 'fish_hilsa', 'bn': 'ইলিশ মাছ', 'en': 'Hilsa Fish', 'unit': 'কেজি', 'category': 'মাছ', 'base': 1200.0},
    {'id': 'fish_pangash', 'bn': 'পাঙ্গাস মাছ', 'en': 'Pangash Fish', 'unit': 'কেজি', 'category': 'মাছ', 'base': 160.0},
    {'id': 'fish_tilapia', 'bn': 'তেলাপিয়া মাছ', 'en': 'Tilapia Fish', 'unit': 'কেজি', 'category': 'মাছ', 'base': 200.0},
  ];
}
