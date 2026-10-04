import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/diagnosis.dart';
import '../models/disease.dart';
import 'local_store.dart';

/// Curated, read-only disease & pest reference library bundled with the app.
///
/// This is NOT user-generated content — it's a small static knowledge base
/// (rice blast, potato late blight, tomato curl, etc.) that the AI chat and
/// crop doctor reference when matching symptoms.
class DiseaseLibraryRepository {
  DiseaseLibraryRepository();

  Future<List<Disease>> all() async => _bundled;

  Future<List<Disease>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    final list = await all();
    return list.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.cropName.toLowerCase().contains(q) ||
          d.symptoms.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  Future<List<Disease>> byCategory(String category) async {
    final list = await all();
    if (category.isEmpty) return list;
    return list.where((d) => d.category == category).toList();
  }

  /// Bundled reference list — see `lib/data/library/disease_library.dart`
  /// for the source data. Kept inline here so the repo has no other file
  /// dependencies.
  static const List<Disease> _bundled = <Disease>[
    Disease(
      id: 'dis-rice-blast',
      name: 'ধানের পাতা পোড়া (Leaf Blast)',
      cropName: 'ধান',
      category: 'rice',
      severity: Severity.medium,
      symptoms: [
        'পাতায় ছোট ছোট ভেজা দাগ',
        'দাগগুলো বড় হয়ে ডায়মন্ড আকার ধারণ করে',
        'আক্রান্ত পাতা শুকিয়ে যায়',
      ],
      causes: [
        'Magnaporthe oryzae ছত্রাক',
        'অতিরিক্ত আর্দ্রতা ও কুয়াশা',
        'নাইট্রোজেন সারের অতিরিক্ত ব্যবহার',
      ],
      prevention: [
        'রোগ প্রতিরোধী জাত যেমন BR-11 ব্যবহার',
        'বীজ শোধন করা',
        'সুষম সার ব্যবহার ও সঠিক দূরত্বে রোপণ',
      ],
      management: [
        'অনুমোদিত ছত্রাকনাশক স্থানীয় কৃষি কর্মকর্তার পরামর্শে ব্যবহার করুন',
        'আক্রান্ত পাতা সংগ্রহ করে ধ্বংস করুন',
        'জমিতে পানি কম রাখুন',
      ],
    ),
    Disease(
      id: 'dis-rice-blight',
      name: 'ধানের বাদামি দাগ (Brown Spot)',
      cropName: 'ধান',
      category: 'rice',
      severity: Severity.low,
      symptoms: ['পাতায় বাদামি গোলাকার দাগ', 'বীজে কালো দাগ'],
      causes: ['Bipolaris oryzae ছত্রাক', 'মাটিতে পটাশের ঘাটতি'],
      prevention: ['পটাশ সার সঠিক মাত্রায় ব্যবহার', 'পরিষ্কার বীজ ব্যবহার'],
      management: [
        'অনুমোদিত ছত্রাকনাশক স্থানীয় কৃষি কর্মকর্তার পরামর্শে ব্যবহার',
      ],
    ),
    Disease(
      id: 'dis-potato-late',
      name: 'আলুর নাবী ধ্বসা (Late Blight)',
      cropName: 'আলু',
      category: 'potato',
      severity: Severity.high,
      symptoms: [
        'পাতার কিনারায় পানি ভেজা দাগ',
        'পাতার নিচে সাদা ছাতার মতো ছাঁচ',
        'কন্দ পচে যায়',
      ],
      causes: ['Phytophthora infestans', 'ঠান্ডা ও আর্দ্র আবহাওয়া'],
      prevention: ['রোগমুক্ত বীজ', 'উঁচু বেডে চাষ', 'ফসল আবর্তন'],
      management: ['অনুমোদিত ছত্রাকনাশক ব্যবহার', 'আক্রান্ত গাছ তুলে ধ্বংস'],
    ),
    Disease(
      id: 'dis-tomato-curl',
      name: 'টমেটোর কার্ল ভাইরাস',
      cropName: 'টমেটো',
      category: 'tomato',
      severity: Severity.medium,
      symptoms: ['পাতা কুঁচকানো', 'গাছ খাটো হওয়া', 'ফল কম ধরা'],
      causes: ['সাদা মাছি (Whitefly) দ্বারা ছড়ায়'],
      prevention: [
        'সাদা মাছি নিয়ন্ত্রণ',
        'হলুদ ফাঁদ ব্যবহার',
        'নেট দিয়ে চারা রক্ষা',
      ],
      management: [
        'আক্রান্ত গাছ অপসারণ',
        'স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন',
      ],
    ),
    Disease(
      id: 'dis-jute-anthracnose',
      name: 'পাটের অ্যানথ্রাকনোজ',
      cropName: 'পাট',
      category: 'jute',
      severity: Severity.low,
      symptoms: ['কান্ডে কালো দাগ', 'চারা শুকিয়ে যাওয়া'],
      causes: ['Colletotrichum corchorum ছত্রাক'],
      prevention: ['সুস্থ বীজ ব্যবহার', 'ফসল আবর্তন'],
      management: ['অনুমোদিত ছত্রাকনাশক ব্যবহার'],
    ),
    Disease(
      id: 'dis-wheat-rust',
      name: 'গমের পাতার মরিচা (Rust)',
      cropName: 'গম',
      category: 'wheat',
      severity: Severity.medium,
      symptoms: ['পাতায় কমলা/বাদামি পাউডারের মতো দাগ'],
      causes: ['Puccinia spp. ছত্রাক'],
      prevention: ['প্রতিরোধী জাত ব্যবহার', 'সঠিক সময়ে বপন'],
      management: ['অনুমোদিত ছত্রাকনাশক ব্যবহার'],
    ),
    Disease(
      id: 'dis-veg-aphid',
      name: 'সবজিতে জাব পোকা',
      cropName: 'সবজি',
      category: 'vegetable',
      severity: Severity.low,
      symptoms: ['পাতা কুঁচকানো', 'পাতায় আঠালো পদার্থ'],
      causes: ['জাব পোকার আক্রমণ'],
      prevention: ['নিম তেল স্প্রে', 'প্রাকৃতিক শত্রু সংরক্ষণ'],
      management: [
        'অনুমোদিত কীটনাশক স্থানীয় কৃষি কর্মকর্তার পরামর্শে ব্যবহার',
      ],
    ),
    Disease(
      id: 'dis-fruit-fruitfly',
      name: 'ফলের ফলের মাছি',
      cropName: 'ফল',
      category: 'fruit',
      severity: Severity.medium,
      symptoms: ['ফলে ছিদ্র ও পচন'],
      causes: ['Bactrocera spp.'],
      prevention: ['ফেরোমন ফাঁদ ব্যবহার', 'আক্রান্ত ফল সংগ্রহ করে ধ্বংস'],
      management: ['অনুমোদিত কীটনাশক ব্যবহার'],
    ),
  ];
}

class DiagnosisRepository {
  DiagnosisRepository(this._store);

  static const _key = 'diagnoses';
  final LocalStore _store;

  /// Returns the user's scan history. Empty list if no scans have been
  /// saved yet — the app does not pre-seed with demo diagnoses.
  ///
  /// On first read after a fresh install / new device, hydrates from
  /// Firestore (when a phone scope is available) so a re-installed app
  /// still sees the user's full diagnosis history.
  Future<List<Diagnosis>> all() async {
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
          debugPrint(
            '[DiagnosisRepository] remote fetch failed: $e\n$st',
          );
        }
      }
    }
    return const <Diagnosis>[];
  }

  Future<void> save(Diagnosis diagnosis) async {
    final list = await all();
    list.insert(0, diagnosis);
    await _saveList(list);

    // Also write the doc by id so it shows up as its own row in the
    // Firestore console (and so any future per-doc queries work).
    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.diagnosisDoc(phone, diagnosis.id).set(diagnosis.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[DiagnosisRepository] shadow write failed: $e\n$st',
        );
      }
    }
  }

  Future<void> delete(String id) async {
    final list = await all();
    list.removeWhere((d) => d.id == id);
    await _saveList(list);

    final phone = _store.phoneKey;
    if (phone == null) return;
    try {
      await FsPaths.diagnosisDoc(phone, id).delete();
    } catch (_) {/* best-effort */}
  }

  List<Diagnosis> _readLocal() {
    final raw = _store.readJson(_key);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Diagnosis.fromJson)
          .toList();
    }
    return const <Diagnosis>[];
  }

  Future<void> _saveList(List<Diagnosis> items) async {
    await _store.writeJson(_key, items.map((d) => d.toJson()).toList());
  }

  Future<List<Diagnosis>> _fetchAllRemote(String phone) async {
    final firestore = FirestoreService.boot().instance;
    final qs = await firestore
        .collection('users')
        .doc(phone)
        .collection('diagnoses')
        .orderBy('scannedAt', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    return qs.docs
        .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
        .map((d) => Diagnosis.fromJson(d.data()))
        .toList();
  }
}
