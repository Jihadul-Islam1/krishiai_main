import 'package:flutter/foundation.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/farm.dart';
import 'local_store.dart';

class FarmRepository {
  FarmRepository(this._store);

  static const _key = 'farms';
  final LocalStore _store;

  Future<List<Farm>> farms() async {
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
          debugPrint('[FarmRepository] remote fetch failed: $e\n$st');
        }
      }
    }
    return <Farm>[];
  }

  Future<List<Farm>> farmsForFarmer() async => farms();

  Future<Farm?> farmById(String id) async {
    final all = await farms();
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(Farm farm) async {
    // Defensive copy — `farms()` may return an empty const list on cache miss
    // and remote failure; mutating it would throw "Cannot add to an
    // unmodifiable list".
    final all = List<Farm>.from(await farms());
    final idx = all.indexWhere((f) => f.id == farm.id);
    if (idx >= 0) {
      all[idx] = farm;
    } else {
      all.add(farm);
    }
    await _saveList(all);

    // Per-doc Firestore write so each farm is queryable on its own.
    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.farmDoc(phone, farm.id).set(farm.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FarmRepository] shadow write failed: $e\n$st');
      }
    }
  }

  Future<void> delete(String id) async {
    final all = List<Farm>.from(await farms());
    all.removeWhere((f) => f.id == id);
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.farmDoc(phone, id).delete();
    } catch (_) {/* best-effort */}
  }

  List<Farm> _readLocal() {
    final raw = _store.readJson(_key);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Farm.fromJson)
          .toList();
    }
    return <Farm>[];
  }

  Future<void> _saveList(List<Farm> farms) async {
    await _store.writeJson(_key, farms.map((f) => f.toJson()).toList());
  }

  Future<List<Farm>> _fetchAllRemote(String phone) async {
    final firestore = FirestoreService.boot().instance;
    final qs = await firestore
        .collection('users')
        .doc(phone)
        .collection('farms')
        .get()
        .timeout(const Duration(seconds: 8));
    return qs.docs
        .where((d) => d.exists && d.data().isNotEmpty)
        .map((d) => Farm.fromJson(d.data()))
        .toList();
  }
}
