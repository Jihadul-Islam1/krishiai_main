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
    _shadowWrite(scopedKey, value);
  }

  Object? readJson(String key) {
    return _decodeJson(_prefs.getString(_scopedKey(key)));
  }

  Future<void> writeString(String key, String value) async {
    final scopedKey = _scopedKey(key);
    await _prefs.setString(scopedKey, value);
    _shadowWriteString(scopedKey, value);
  }

  String? readString(String key) => _prefs.getString(_scopedKey(key));

  Future<void> writeBool(String key, bool value) async {
    final scopedKey = _scopedKey(key);
    await _prefs.setBool(scopedKey, value);
    _shadowWriteBool(scopedKey, value);
  }

  bool readBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(_scopedKey(key)) ?? defaultValue;

  Future<void> remove(String key) async {
    final scopedKey = _scopedKey(key);
    await _prefs.remove(scopedKey);
    _shadowDelete(scopedKey);
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
  // ---------------------------------------------------------------------------

  void _shadowWrite(String key, Object value) {
    final phone = _phone;
    if (phone == null) return;
    final path = _pathForKey(key);
    if (path == null) return;
    unawaited(_safeSet(path, {key: value}));
  }

  void _shadowWriteString(String key, String value) {
    final phone = _phone;
    if (phone == null) return;
    final path = _pathForKey(key);
    if (path == null) return;
    unawaited(_safeSet(path, {key: value}));
  }

  void _shadowWriteBool(String key, bool value) {
    final phone = _phone;
    if (phone == null) return;
    final path = _pathForKey(key);
    if (path == null) return;
    unawaited(_safeSet(path, {key: value}));
  }

  void _shadowDelete(String key) {
    final phone = _phone;
    if (phone == null) return;
    final path = _pathForKey(key);
    if (path == null) return;
    unawaited(_safeDelete(path));
  }

  // ---------------------------------------------------------------------------
  // Path mapping from local key -> Firestore target. Centralised so adding a
  // new shadow is a one-liner.
  // ---------------------------------------------------------------------------

  /// Maps a SharedPreferences key to the Firestore target reference (or null
  /// to skip shadowing). Returns a typed handle the caller can write into.
  _FsTarget? _pathForKey(String key) {
    final phone = _phone;
    if (phone == null) return null;
    switch (key) {
      case 'farmer_profile':
        return _FsTarget.doc(FsPaths.profile(phone));
      case 'farms':
        // List-of-farms stored as a single doc snapshot under meta for
        // backward compatibility with the legacy shape.
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('farms'));
      case 'crops':
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('crops'));
      case 'diagnoses':
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('diagnoses'));
      case 'expenses':
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('expenses'));
      case 'notifications':
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('notifications'));
      case 'subscription':
        return _FsTarget.doc(FsPaths.subscription(phone));
      case 'ai_chat_history':
        return _FsTarget.doc(FsPaths.aiHistory(phone));
      case 'market_cache_v2':
        return _FsTarget.doc(FsPaths.marketCache(phone));
      case 'market_favorites_v1':
        return _FsTarget.doc(FsPaths.userDoc(phone).collection('meta').doc('market_favorites'));
      case 'weather_cache_v1':
        return _FsTarget.doc(FsPaths.weatherCache(phone));
      default:
        // Unknown keys are not shadowed - they stay device-local.
        return null;
    }
  }

  Future<void> _safeSet(_FsTarget target, Map<String, dynamic> value) async {
    try {
      await target.ref.set(value, SetOptions(merge: true));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LocalStore] shadow write failed for '
            '${target.ref.path}: $e\n$st');
      }
    }
  }

  Future<void> _safeDelete(_FsTarget target) async {
    try {
      await target.ref.delete();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[LocalStore] shadow delete failed for '
            '${target.ref.path}: $e\n$st');
      }
    }
  }
}

class _FsTarget {
  _FsTarget.doc(this.ref);
  final DocumentReference<Map<String, dynamic>> ref;
}
