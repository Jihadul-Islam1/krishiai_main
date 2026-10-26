import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../models/tool_plan.dart';
import 'local_store.dart';

class ToolPlanRepository {
  ToolPlanRepository(this._store);

  static const key = 'tool_plans';
  final LocalStore _store;

  Future<List<ToolPlan>> all() async {
    final raw = _store.readJson(key);
    if (raw is! List) return <ToolPlan>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ToolPlan.fromJson)
        .toList();
  }

  Future<void> save(ToolPlan plan) async {
    final list = await all();
    list.insert(0, plan);
    await _store.writeLocal(key, list.map((e) => e.toJson()).toList());

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.toolPlanDoc(phone, plan.id).set(plan.toJson());
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ToolPlanRepository] write failed: $e\n$st');
    }
  }
}
