import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../models/farmer.dart';
import 'local_store.dart';

class FarmerRepository {
  FarmerRepository(this._store);

  static const _key = 'farmer_profile';
  final LocalStore _store;

  Future<Farmer?> currentFarmer() async {
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic>) {
      return Farmer.fromJson(raw);
    }

    // Try to hydrate from Firestore so a re-installed app still has the
    // profile (the LocalStore is intentionally the read path for speed;
    // Firestore is the durable source of truth).
    final phone = _store.phoneKey;
    if (phone != null) {
      try {
        final snap = await FsPaths.profile(phone).get();
        final data = snap.data();
        if (data != null && data.isNotEmpty) {
          final farmer = Farmer.fromJson(data);
          await _store.writeJson(_key, data);
          return farmer;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[FarmerRepository] remote fetch failed: $e\n$st',
          );
        }
      }
    }
    return null;
  }

  Future<void> saveFarmer(Farmer farmer) async {
    await _store.writeJson(_key, farmer.toJson());

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.profile(phone).set(farmer.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FarmerRepository] shadow write failed: $e\n$st');
      }
    }
  }

  Future<void> clear() async {
    await _store.remove(_key);
    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.profile(phone).delete();
    } catch (_) {/* best-effort */}
  }
}
