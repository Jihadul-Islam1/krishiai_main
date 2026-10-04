import 'package:flutter/foundation.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/expense.dart';
import 'local_store.dart';

class ExpenseRepository {
  ExpenseRepository(this._store);

  static const _key = 'expenses';
  final LocalStore _store;

  Future<List<Expense>> all() async {
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
          debugPrint('[ExpenseRepository] remote fetch failed: $e\n$st');
        }
      }
    }
    return <Expense>[];
  }

  Future<List<Expense>> forCrop(String cropId) async {
    final all = await this.all();
    return all.where((e) => e.cropId == cropId).toList();
  }

  Future<void> add(Expense expense) async {
    final all = List<Expense>.from(await this.all());
    all.insert(0, expense);
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.expenseDoc(phone, expense.id).set(expense.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ExpenseRepository] shadow write failed: $e\n$st');
      }
    }
  }

  Future<void> delete(String id) async {
    final all = List<Expense>.from(await this.all());
    all.removeWhere((e) => e.id == id);
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.expenseDoc(phone, id).delete();
    } catch (_) {/* best-effort */}
  }

  List<Expense> _readLocal() {
    final raw = _store.readJson(_key);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Expense.fromJson)
          .toList();
    }
    return <Expense>[];
  }

  Future<void> _saveList(List<Expense> items) async {
    await _store.writeJson(_key, items.map((e) => e.toJson()).toList());
  }

  Future<List<Expense>> _fetchAllRemote(String phone) async {
    final firestore = FirestoreService.boot().instance;
    final qs = await firestore
        .collection('users')
        .doc(phone)
        .collection('expenses')
        .orderBy('date', descending: true)
        .get()
        .timeout(const Duration(seconds: 8));
    return qs.docs
        .where((d) => d.exists && d.data().isNotEmpty)
        .map((d) => Expense.fromJson(d.data()))
        .toList();
  }
}
