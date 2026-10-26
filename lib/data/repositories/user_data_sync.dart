import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import 'local_store.dart';

/// Pulls everything stored under `users/{phone}/...` into the phone-scoped
/// local cache, so a farmer who logs in with their number (on a new phone, or
/// after a reinstall) sees the same profile, farms, crops, expenses, scan
/// history, profit records, notifications, etc.
///
/// Firestore is the source of truth: a non-empty remote collection replaces
/// the cached copy. If the remote collection is empty but the device has
/// local data (created before sync existed / while offline), that data is
/// pushed up instead so nothing is lost.
class UserDataSync {
  UserDataSync._();

  /// Local cache key, Firestore collection and the field the list is
  /// sorted by (newest first) - mirrors the order each repository expects.
  static const _lists = <_ListSpec>[
    _ListSpec('farms', 'createdAt'),
    _ListSpec('crops', 'plantingDate'),
    _ListSpec('expenses', 'date'),
    _ListSpec('diagnoses', 'scannedAt'),
    _ListSpec('notifications', 'createdAt'),
    _ListSpec('profit_records', 'savedAt'),
    _ListSpec('tool_plans', 'savedAt'),
    _ListSpec('photos', 'createdAt'),
  ];

  static Future<void> pull(LocalStore store) async {
    final phone = store.phoneKey;
    if (phone == null) return;
    try {
      await Future.wait<void>([
        for (final spec in _lists) _pullList(store, phone, spec),
        _pullDoc(store, 'farmer_profile', FsPaths.profile(phone)),
        _pullDoc(store, 'subscription', FsPaths.subscription(phone)),
        _pullDoc(store, 'ai_chat_history', FsPaths.aiHistory(phone)),
        for (final e in LocalStore.shadowedDocs.entries)
          _pullMeta(store, phone, e.key, e.value),
      ]).timeout(const Duration(seconds: 10));
    } catch (e, st) {
      // Offline / slow network: keep whatever is cached locally.
      if (kDebugMode) debugPrint('[UserDataSync] pull failed: $e\n$st');
    }
  }

  static Future<void> _pullList(
    LocalStore store,
    String phone,
    _ListSpec spec,
  ) async {
    try {
      final col = FsPaths.userDoc(phone).collection(spec.collection);
      final snap = await col.get();
      if (snap.docs.isNotEmpty) {
        final items = [for (final d in snap.docs) d.data()]
          ..sort((a, b) => '${b[spec.sortField] ?? ''}'
              .compareTo('${a[spec.sortField] ?? ''}'));
        await store.writeLocal(spec.collection, items);
        return;
      }
      final local = store.readJson(spec.collection);
      if (local is List && local.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final item in local.whereType<Map<String, dynamic>>()) {
          final id = item['id'];
          if (id is String && id.isNotEmpty) batch.set(col.doc(id), item);
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UserDataSync] ${spec.collection}: $e');
    }
  }

  static Future<void> _pullDoc(
    LocalStore store,
    String key,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final data = (await ref.get()).data();
      if (data != null && data.isNotEmpty) {
        await store.writeLocal(key, data);
        return;
      }
      final local = store.readJson(key);
      if (local is Map<String, dynamic> && local.isNotEmpty) {
        await ref.set(local);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UserDataSync] $key: $e');
    }
  }

  static Future<void> _pullMeta(
    LocalStore store,
    String phone,
    String key,
    String doc,
  ) async {
    try {
      final ref = FsPaths.userDoc(phone).collection('meta').doc(doc);
      final data = (await ref.get()).data()?['data'];
      if (data != null) {
        await store.writeLocal(key, data);
        return;
      }
      final local = store.readJson(key);
      if (local != null) {
        await ref.set({
          'data': local,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UserDataSync] meta/$doc: $e');
    }
  }
}

class _ListSpec {
  const _ListSpec(this.collection, this.sortField);
  final String collection;
  final String sortField;
}
