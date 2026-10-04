import 'package:flutter/foundation.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/crop.dart';
import 'local_store.dart';

class CropRepository {
  CropRepository(this._store);

  static const _key = 'crops';
  final LocalStore _store;

  Future<List<Crop>> crops() async {
    final cached = _readLocal();
    if (cached.isNotEmpty) return cached;

    final phone = _store.phoneKey;
    if (phone != null) {
      try {
        final remote = await _fetchAllRemote(phone);
        if (remote.isNotEmpty) {
          await _saveList(remote);
          return remote;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CropRepository] remote fetch failed: $e\n$st');
        }
      }
    }
    return <Crop>[];
  }

  Future<List<Crop>> cropsForFarm(String farmId) async {
    final all = await crops();
    return all.where((c) => c.farmId == farmId).toList();
  }

  Future<Crop?> cropById(String id) async {
    final all = await crops();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(Crop crop) async {
    // Defensive copy — `crops()` may return the cached list (mutable) but
    // could in theory return an empty const list on cache miss + remote
    // failure, and mutating it would throw "Unsupported operation: Cannot
    // add to an unmodifiable list".
    final all = List<Crop>.from(await crops());
    final idx = all.indexWhere((c) => c.id == crop.id);
    if (idx >= 0) {
      all[idx] = crop;
    } else {
      all.add(crop);
    }
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.cropDoc(phone, crop.id).set(crop.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CropRepository] shadow write failed: $e\n$st');
      }
    }
  }

  Future<void> delete(String id) async {
    final all = List<Crop>.from(await crops());
    all.removeWhere((c) => c.id == id);
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.cropDoc(phone, id).delete();
    } catch (_) {/* best-effort */}
  }

  List<Crop> _readLocal() {
    final raw = _store.readJson(_key);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Crop.fromJson)
          .toList();
    }
    return <Crop>[];
  }

  Future<void> _saveList(List<Crop> crops) async {
    await _store.writeJson(_key, crops.map((c) => c.toJson()).toList());
  }

  Future<List<Crop>> _fetchAllRemote(String phone) async {
    final firestore = FirestoreService.boot().instance;
    final qs = await firestore
        .collection('users')
        .doc(phone)
        .collection('crops')
        .orderBy('plantingDate', descending: true)
        .get()
        .timeout(const Duration(seconds: 8));
    return qs.docs
        .where((d) => d.exists && d.data().isNotEmpty)
        .map((d) => Crop.fromJson(d.data()))
        .toList();
  }
}
