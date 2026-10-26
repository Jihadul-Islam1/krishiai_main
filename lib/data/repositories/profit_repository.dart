import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../models/profit_estimate.dart';
import 'local_store.dart';

/// Saved profit/loss calculations (`users/{phone}/profit_records/{id}`).
class ProfitRepository {
  ProfitRepository(this._store);

  static const key = 'profit_records';
  final LocalStore _store;

  Future<List<ProfitEstimate>> all() async {
    final raw = _store.readJson(key);
    if (raw is! List) return <ProfitEstimate>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProfitEstimate.fromJson)
        .toList();
  }

  Future<void> save(ProfitEstimate estimate) async {
    final list = await all();
    list.insert(0, estimate);
    await _store.writeLocal(key, list.map((e) => e.toJson()).toList());

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.profitRecordDoc(phone, estimate.id).set(estimate.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ProfitRepository] write failed: $e\n$st');
      }
    }
  }

  Future<void> delete(String id) async {
    final list = await all()
      ..removeWhere((e) => e.id == id);
    await _store.writeLocal(key, list.map((e) => e.toJson()).toList());

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.profitRecordDoc(phone, id).delete();
    } catch (_) {/* best-effort */}
  }
}
