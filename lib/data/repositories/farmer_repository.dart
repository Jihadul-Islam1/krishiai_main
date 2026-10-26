import 'package:flutter/foundation.dart';

import '../../core/services/fs_paths.dart';
import '../models/farmer.dart';
import 'local_store.dart';

/// The logged-in farmer's profile, stored at `users/{phone}/profile/me`.
/// The phone number the farmer logged in with is the document key, so every
/// number gets its own profile.
class FarmerRepository {
  FarmerRepository(this._store);

  static const _key = 'farmer_profile';
  final LocalStore _store;

  /// Returns the profile for the current phone. On the very first login for a
  /// number no profile exists yet, so an empty one is created (and written to
  /// Firestore) - the farmer then fills it in from the Profile tab.
  Future<Farmer?> currentFarmer() async {
    final phone = _store.phoneKey;
    final raw = _store.readJson(_key);
    if (raw is Map<String, dynamic> && raw.isNotEmpty) {
      return Farmer.fromJson(raw);
    }
    if (phone == null) return null;

    try {
      final snap = await FsPaths.profile(phone).get();
      final data = snap.data();
      if (data != null && data.isNotEmpty) {
        await _store.writeLocal(_key, data);
        return Farmer.fromJson(data);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FarmerRepository] remote fetch failed: $e\n$st');
      }
    }

    // Adopt the profile typed into the pre-login setup form, if any.
    final anon = await _store.takeAnonymousJson(_key);
    if (anon is Map<String, dynamic> && anon.isNotEmpty) {
      final adopted = Farmer.fromJson(anon).copyWith(phone: phone);
      await saveFarmer(adopted);
      return adopted;
    }

    final now = DateTime.now();
    final fresh = Farmer(
      id: 'farmer-${now.millisecondsSinceEpoch}',
      name: '',
      district: '',
      upazila: '',
      experienceYears: 0,
      farmSizeAcres: 0,
      mainCrop: '',
      language: 'bn',
      phone: phone,
      createdAt: now,
      updatedAt: now,
    );
    await saveFarmer(fresh);
    return fresh;
  }

  Future<void> saveFarmer(Farmer farmer) async {
    final phone = _store.phoneKey;
    final toSave = farmer.copyWith(
      phone: phone ?? farmer.phone,
      updatedAt: DateTime.now(),
    );
    await _store.writeLocal(_key, toSave.toJson());

    if (phone == null) return;
    try {
      await FsPaths.profile(phone).set(toSave.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FarmerRepository] remote write failed: $e\n$st');
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
