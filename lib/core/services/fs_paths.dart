import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/phone_key.dart';

/// Single source of truth for every Firestore path used by the app.
///
/// All sub-collections live under `users/{phone}/...` so multi-tenant data
/// stays scoped per verified phone number. Repositories must construct their
/// CollectionReference/DocumentReference via these helpers instead of
/// hard-coding paths.
class FsPaths {
  FsPaths._();

  // ---------------------------------------------------------------------------
  // users/{phone}
  // ---------------------------------------------------------------------------
  static DocumentReference<Map<String, dynamic>> userDoc(String phone) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(PhoneKey.require(phone));
  }

  // ---------------------------------------------------------------------------
  // users/{phone}/profile
  // Single doc that holds the farmer's profile (Farmer.toJson()).
  // ---------------------------------------------------------------------------
  static DocumentReference<Map<String, dynamic>> profile(String phone) {
    return userDoc(phone).collection('profile').doc('me');
  }

  // ---------------------------------------------------------------------------
  // users/{phone}/farms | crops | diagnoses | expenses | notifications
  // ---------------------------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> farms(String phone) =>
      userDoc(phone).collection('farms');
  static CollectionReference<Map<String, dynamic>> crops(String phone) =>
      userDoc(phone).collection('crops');
  static CollectionReference<Map<String, dynamic>> diagnoses(String phone) =>
      userDoc(phone).collection('diagnoses');
  static CollectionReference<Map<String, dynamic>> expenses(String phone) =>
      userDoc(phone).collection('expenses');
  static CollectionReference<Map<String, dynamic>> notifications(String phone) =>
      userDoc(phone).collection('notifications');
  static CollectionReference<Map<String, dynamic>> profitRecords(String phone) =>
      userDoc(phone).collection('profit_records');
  static DocumentReference<Map<String, dynamic>> photoDoc(
    String phone,
    String id,
  ) => userDoc(phone).collection('photos').doc(id);
  static DocumentReference<Map<String, dynamic>> toolPlanDoc(
    String phone,
    String id,
  ) => userDoc(phone).collection('tool_plans').doc(id);
  static DocumentReference<Map<String, dynamic>> profitRecordDoc(
    String phone,
    String id,
  ) => profitRecords(phone).doc(id);

  static DocumentReference<Map<String, dynamic>> farmDoc(String phone, String id) =>
      farms(phone).doc(id);
  static DocumentReference<Map<String, dynamic>> cropDoc(String phone, String id) =>
      crops(phone).doc(id);
  static DocumentReference<Map<String, dynamic>> diagnosisDoc(String phone, String id) =>
      diagnoses(phone).doc(id);
  static DocumentReference<Map<String, dynamic>> expenseDoc(String phone, String id) =>
      expenses(phone).doc(id);
  static DocumentReference<Map<String, dynamic>> notificationDoc(String phone, String id) =>
      notifications(phone).doc(id);

  // ---------------------------------------------------------------------------
  // users/{phone}/subscription  (single doc)
  // users/{phone}/ai_history   (single doc, messages array)
  // users/{phone}/weather_cache (single doc, snapshot map)
  // ---------------------------------------------------------------------------
  static DocumentReference<Map<String, dynamic>> subscription(String phone) =>
      userDoc(phone).collection('meta').doc('subscription');
  static DocumentReference<Map<String, dynamic>> aiHistory(String phone) =>
      userDoc(phone).collection('meta').doc('ai_history');
  static DocumentReference<Map<String, dynamic>> weatherCache(String phone) =>
      userDoc(phone).collection('meta').doc('weather_cache');
  static DocumentReference<Map<String, dynamic>> settings(String phone) =>
      userDoc(phone).collection('meta').doc('settings');

  // ---------------------------------------------------------------------------
  // users/{phone}/market_favorites | market_cache
  // ---------------------------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> marketFavorites(String phone) =>
      userDoc(phone).collection('market_favorites');
  static DocumentReference<Map<String, dynamic>> marketCache(String phone) =>
      userDoc(phone).collection('meta').doc('market_cache');

  // ---------------------------------------------------------------------------
  // market_prices_live (global, NOT under users/{phone})
  //
  // Each document id is the crop id (e.g. `potato`, `rice_miniket`). Admin
  // tools upsert the latest DAM-sourced entry per crop daily. The mobile
  // client reads the newest doc per id, sorts/merges it over the bundled
  // fallback catalog, and caches the merged snapshot locally.
  // ---------------------------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> marketPricesLive() =>
      FirebaseFirestore.instance.collection('market_prices_live');
  static DocumentReference<Map<String, dynamic>> marketPriceLiveDoc(String id) =>
      marketPricesLive().doc(id);
}
