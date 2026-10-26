import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/fs_paths.dart';
import '../../core/utils/phone_key.dart';

/// Thin wrapper over [SharedPreferences] (local cache) plus an automatic
/// Firestore shadow-write under `users/{phone}/...` for every mutation.
///
/// The local cache still serves as the read path so the existing UI does
/// not need to change; the Firestore write happens after a successful local
/// write so we never persist data the OS has rejected. If the user signs
/// out and another user signs in on the same device, every read becomes
/// phone-scoped because [_phone] is supplied at construction time.
class LocalStore {
  LocalStore(this._prefs, {this._phone});

  final SharedPreferences _prefs;
  String? _phone;

  /// The verified bdapps phone number, sanitised via [PhoneKey.fromString].
  /// When `null`, all writes are local-only (anonymous / pre-auth state).

  /// Updates the phone context. Triggers a no-op read on the next call so
  /// future reads/writes land in the new phone scope.
  void setPhone(String? phone) {
    final newKey = PhoneKey.fromString(phone);
    if (newKey != _phone) {
      _phone = newKey;
    }
  }

  String? get phoneKey => _phone;

  // ---------------------------------------------------------------------------
  // Core JSON API - local-only path that callers already use.
  // ---------------------------------------------------------------------------

  Future<void> writeJson(String key, Object value) async {
    final scopedKey = _scopedKey(key);
    await _prefs.setString(scopedKey, jsonEncode(value));
    _shadowWrite(key, value);
  }

  /// Local-only write. Used by repositories that already persist to
  /// Firestore per-document themselves, and by [UserDataSync] when it
  /// hydrates the cache from Firestore.
  Future<void> writeLocal(String key, Object value) =>
      _prefs.setString(_scopedKey(key), jsonEncode(value));

  Object? readJson(String key) {
    return _decodeJson(_prefs.getString(_scopedKey(key)));
  }

  Future<void> writeString(String key, String value) async {
    final scopedKey = _scopedKey(key);
    await _prefs.setString(scopedKey, value);
    _shadowWrite(key, value);
  }

  /// Reads (and removes) a value saved before login, when no phone scope
  /// existed yet - e.g. the onboarding profile-setup form.
  Future<Object?> takeAnonymousJson(String key) async {
    final value = _decodeJson(_prefs.getString(key));
    if (value != null) await _prefs.remove(key);
    return value;
  }

  String? readString(String key) => _prefs.getString(_scopedKey(key));

  Future<void> writeBool(String key, bool value) async {
    final scopedKey = _scopedKey(key);
    await _prefs.setBool(scopedKey, value);
    _shadowWrite(key, value);
  }

  bool readBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(_scopedKey(key)) ?? defaultValue;

  Future<void> remove(String key) async {
    final scopedKey = _scopedKey(key);
    await _prefs.remove(scopedKey);
    _shadowDelete(key);
  }

  Future<void> clearAll() async {
    // Only clear phone-scoped keys so we do not wipe anonymous / onboarding
    // flags like `krishiai.onboardingDone`.
    if (_phone == null) {
      await _prefs.clear();
      return;
    }
    final prefix = '$_phone::';
    final allKeys = _prefs.getKeys();
    for (final k in allKeys) {
      if (k.startsWith(prefix)) {
        await _prefs.remove(k);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String _scopedKey(String key) {
    final p = _phone;
    if (p == null) return key;
    return '$p::$key';
  }

  Object? _decodeJson(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore shadow writes - best-effort, fire-and-forget; we never let a
  // remote failure abort a local write.
  //
  // Only keys listed in [shadowedDocs] are mirrored here. Farmer, farms,
  // crops, expenses, diagnoses, notifications, profit records, subscription
  // and AI history are written by their own repositories (per-document), so
  // they are intentionally absent.
  // ---------------------------------------------------------------------------

  /// Local key -> doc id under `users/{phone}/meta/{doc}`. The payload is
  /// stored as `{data: <value>, updatedAt: <server time>}`.
  static const Map<String, String> shadowedDocs = {
    'market_favorites_v1': 'market_favorites',
    'market_cache_v2': 'market_cache',
    'weather_cache_v1': 'weather_cache',
  };

  DocumentReference<Map<String, dynamic>>? _metaRef(String key) {
    final phone = _phone;
    final doc = shadowedDocs[key];
    if (phone == null || doc == null) return null;
    return FsPaths.userDoc(phone).collection('meta').doc(doc);
  }

  void _shadowWrite(String key, Object value) {
    final ref = _metaRef(key);
    if (ref == null) return;
    unawaited(_safe(
      ref.path,
      () => ref.set({
        'data': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ));
  }

  void _shadowDelete(String key) {
    final ref = _metaRef(key);
    if (ref == null) return;
    unawaited(_safe(ref.path, ref.delete));
  }

  Future<void> _safe(String path, Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LocalStore] shadow op failed for $path: $e\n$st');
      }
    }
  }
}
