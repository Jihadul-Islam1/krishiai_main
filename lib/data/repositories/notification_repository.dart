import 'package:flutter/foundation.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/app_notification.dart';
import 'local_store.dart';

class NotificationRepository {
  NotificationRepository(this._store);

  static const _key = 'notifications';
  final LocalStore _store;

  Future<List<AppNotification>> all() async {
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
          debugPrint('[NotificationRepository] remote fetch failed: $e\n$st');
        }
      }
    }
    return const <AppNotification>[];
  }

  Future<void> add(AppNotification notification) async {
    final all = await this.all();
    all.insert(0, notification);
    await _saveList(all);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.notificationDoc(phone, notification.id)
          .set(notification.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationRepository] shadow write failed: $e\n$st',
        );
      }
    }
  }

  Future<void> markAllRead() async {
    final all = await this.all();
    final updated = all.map((n) => n.copyWith(isRead: true)).toList();
    await _saveList(updated);

    final phone = _store.phoneKey;
    if (phone == null) return;
    // Best-effort bulk update so the read flag also flips server-side.
    for (final n in updated) {
      try {
        await FsPaths.notificationDoc(phone, n.id).set(n.toJson());
      } catch (_) {/* swallow */}
    }
  }

  Future<void> markRead(String id) async {
    final all = await this.all();
    final updated = [
      for (final n in all)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    await _saveList(updated);

    final phone = _store.phoneKey;
    if (phone == null) return;
    final changed = updated.firstWhere(
      (n) => n.id == id,
      orElse: () => all.firstWhere((n) => n.id == id),
    );
    try {
      await FsPaths.notificationDoc(phone, id).set(changed.toJson());
    } catch (_) {/* best-effort */}
  }

  Future<int> unreadCount() async {
    final all = await this.all();
    return all.where((n) => !n.isRead).length;
  }

  List<AppNotification> _readLocal() {
    final raw = _store.readJson(_key);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    }
    return const <AppNotification>[];
  }

  Future<void> _saveList(List<AppNotification> items) async {
    await _store.writeJson(_key, items.map((n) => n.toJson()).toList());
  }

  Future<List<AppNotification>> _fetchAllRemote(String phone) async {
    final firestore = FirestoreService.boot().instance;
    final qs = await firestore
        .collection('users')
        .doc(phone)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .get()
        .timeout(const Duration(seconds: 8));
    return qs.docs
        .where((d) => d.exists && d.data().isNotEmpty)
        .map((d) => AppNotification.fromJson(d.data()))
        .toList();
  }
}
