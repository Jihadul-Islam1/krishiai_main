import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/network/disease_api_service.dart';
import '../../core/services/fs_paths.dart';
import '../models/ai_chat.dart';
import '../models/diagnosis.dart';
import '../models/disease.dart';
import 'disease_repository.dart';
import 'local_store.dart';

const _uuid = Uuid();

class AIRepository {
  AIRepository(this._diseaseRepo, this._store);

  final DiseaseLibraryRepository _diseaseRepo;
  final LocalStore _store;

  static const _historyKey = 'ai_chat_history';

  Future<Diagnosis> analyzeImagePlaceholder({
    required String cropName,
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final library = await _diseaseRepo.all();
    final lower = cropName.toLowerCase();
    Disease match = library.first;
    for (final d in library) {
      if (d.cropName.toLowerCase() == lower) {
        match = d;
        break;
      }
    }
    return Diagnosis(
      id: _uuid.v4(),
      cropName: cropName,
      diseaseName: match.name,
      confidence: 0.85,
      severity: match.severity,
      scannedAt: DateTime.now(),
      symptoms: match.symptoms,
      causes: match.causes,
      management: match.management,
      prevention: match.prevention,
      notes: notes,
    );
  }

  Future<DiseaseInferenceResult?> analyzeImageWithModel({
    required String cropName,
    String? imagePath,
    String? notes,
  }) async {
    final api = DiseaseApiService();
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          final result = await api.predictImage(file);
          if (kDebugMode) {
            debugPrint(
              '[AIRepository] /predict ok top1=${result.topK.isNotEmpty ? result.topK.first.label : '-'} inferenceMs=${result.inferenceMs}',
            );
          }
          return result;
        }
      }
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AIRepository] /predict failed, falling back: $e\n$st');
      }
      return null;
    } finally {
      api.dispose();
    }
  }

  Future<Diagnosis> diagnosisFromInference({
    required String cropName,
    required DiseaseInferenceResult result,
    String? notes,
  }) async {
    return _mapResultToDiagnosis(
      cropName: cropName,
      notes: notes,
      result: result,
    );
  }

  Severity _severityFromString(String s) {
    switch (s.toLowerCase()) {
      case 'low':
        return Severity.low;
      case 'high':
        return Severity.high;
      default:
        return Severity.medium;
    }
  }

  Future<Diagnosis> _mapResultToDiagnosis({
    required String cropName,
    required DiseaseInferenceResult result,
    String? notes,
  }) async {
    if (result.topK.isEmpty) {
      return analyzeImagePlaceholder(cropName: cropName, notes: notes);
    }
    final top1 = result.topK.first;
    final adv = result.advisory;
    List<String> toStrs(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return Future<Diagnosis>.value(
      Diagnosis(
        id: _uuid.v4(),
        cropName: cropName,
        diseaseName: top1.labelBn,
        confidence: top1.confidence,
        severity: _severityFromString(top1.severity),
        scannedAt: DateTime.now(),
        symptoms: toStrs(adv['symptoms']),
        causes: toStrs(adv['causes']),
        management: toStrs(adv['management']),
        prevention: toStrs(adv['prevention']),
        notes: notes,
      ),
    );
  }

  Future<AIConversation> loadConversation() async {
    final raw = _store.readJson(_historyKey);
    if (raw is Map<String, dynamic>) {
      try {
        return AIConversation.fromJson(raw);
      } catch (_) {}
    }

    final phone = _store.phoneKey;
    if (phone != null) {
      try {
        final snap = await FsPaths.aiHistory(phone).get();
        final data = snap.data();
        if (data != null && data.isNotEmpty) {
          final conv = AIConversation.fromJson(data);
          await _store.writeJson(_historyKey, data);
          return conv;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[AIRepository] remote fetch failed: $e\n$st');
        }
      }
    }

    final now = DateTime.now();
    return AIConversation(
      id: _uuid.v4(),
      title: 'নতুন কথোপকথন',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<AIConversation> appendMessage(
    AIConversation conv,
    AIMessage message,
  ) async {
    final updated = conv.copyWith(
      messages: [...conv.messages, message],
      updatedAt: DateTime.now(),
    );
    await _store.writeJson(_historyKey, updated.toJson());

    final phone = _store.phoneKey;
    if (phone == null) return updated;
    try {
      await FsPaths.aiHistory(phone).set(updated.toJson());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AIRepository] shadow write failed: $e\n$st');
      }
    }
    return updated;
  }

  /// OpenRouter API via HTTP
  /// OpenRouter API via HTTP
  Future<AIMessage> generateReply(String userText) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: '.env ফাইলে OPENROUTER_API_KEY পাওয়া যায়নি।',
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://krishiai.app',
          'X-Title': 'KrishiAI',
        },
        body: jsonEncode({
          'model':
              'openrouter/free', // <--- এখানে সম্পূর্ণ ফ্রি মডেল বসানো হয়েছে
          'messages': [
            {
              'role': 'system',
              'content':
                  'তুমি একজন অভিজ্ঞ বাংলা কৃষি বিশেষজ্ঞ সহকারী। উত্তরগুলো সহজ ও সংক্ষেপে বাংলা ভাষায় দাও।',
            },
            {'role': 'user', 'content': userText},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final replyText = data['choices'][0]['message']['content'];
        return AIMessage(
          id: _uuid.v4(),
          role: AIMessageRole.assistant,
          content: replyText,
          createdAt: DateTime.now(),
        );
      } else {
        final err = jsonDecode(response.body);
        return AIMessage(
          id: _uuid.v4(),
          role: AIMessageRole.assistant,
          content:
              'OpenRouter এরর (${response.statusCode}): ${err['error']?['message'] ?? 'সমস্যা হয়েছে'}',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      return AIMessage(
        id: _uuid.v4(),
        role: AIMessageRole.assistant,
        content: 'ইন্টারনেট সংযোগ বা API কল করতে সমস্যা হচ্ছে। এরর: $e',
        createdAt: DateTime.now(),
      );
    }
  }
  /// Clear conversation history
  Future<void> clearConversation() async {
    await _store.writeJson(
      _historyKey,
      <String, dynamic>{},
    ); // null-এর জায়গায় {} বসানো হয়েছে
    final phone = _store.phoneKey;
    if (phone != null) {
      try {
        await FsPaths.aiHistory(phone).delete();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AIRepository] remote clear failed: $e');
        }
      }
    }
  }
}
