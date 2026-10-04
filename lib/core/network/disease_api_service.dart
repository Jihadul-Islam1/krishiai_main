import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Single top-K prediction returned by the FastAPI `/predict` endpoint.
@immutable
class DiseasePrediction {
  const DiseasePrediction({
    required this.label,
    required this.labelBn,
    required this.labelEn,
    required this.confidence,
    required this.severity,
  });

  final String label;
  final String labelBn;
  final String labelEn;
  final double confidence;
  final String severity; // 'low' | 'medium' | 'high'

  factory DiseasePrediction.fromJson(Map<String, dynamic> json) =>
      DiseasePrediction(
        label: json['label'] as String,
        labelBn: json['label_bn'] as String? ?? json['label'] as String,
        labelEn: json['label_en'] as String? ?? json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        severity: json['severity'] as String? ?? 'medium',
      );
}

/// Rich response from `/predict`. Includes the top-K list plus Bangla
/// advisory copy for the leading prediction and a server-rendered
/// disclaimer line so the UI can surface it verbatim.
@immutable
class DiseaseInferenceResult {
  const DiseaseInferenceResult({
    required this.topK,
    required this.isConfident,
    required this.probable,
    required this.advisory,
    required this.noteBn,
    required this.modelVersion,
    required this.inferenceMs,
  });

  final List<DiseasePrediction> topK;
  final bool isConfident;
  final bool probable;
  final Map<String, dynamic> advisory;
  final String noteBn;
  final String modelVersion;
  final int inferenceMs;

  DiseasePrediction get top1 => topK.first;

  factory DiseaseInferenceResult.fromJson(Map<String, dynamic> json) {
    final list = (json['top_k'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiseasePrediction.fromJson)
        .toList();
    return DiseaseInferenceResult(
      topK: list,
      isConfident: json['is_confident'] as bool? ?? false,
      probable: json['probable'] as bool? ?? false,
      advisory: (json['advisory'] as Map?)?.cast<String, dynamic>() ?? const {},
      noteBn: json['note_bn'] as String? ?? '',
      modelVersion: json['model_version'] as String? ?? 'unknown',
      inferenceMs: (json['inference_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Thrown when the backend is unreachable or returns a non-2xx
/// response. The Crop Doctor UI catches this and falls back to the
/// library-only advisor so the demo never breaks.
class DiseaseApiException implements Exception {
  DiseaseApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'DiseaseApiException($statusCode): $message';
}

/// HTTP client wrapper that talks to the FastAPI `/predict` endpoint.
class DiseaseApiService {
  DiseaseApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Lightweight ping. Returns `true` if the server responds 2xx.
  Future<bool> ping() async {
    try {
      final r = await _client
          .get(_uri(ApiConfig.healthPath))
          .timeout(const Duration(seconds: 3));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Posts an image to `/predict`. Accepts either a `File` (mobile)
  /// or raw bytes (tests / web). Returns the parsed inference
  /// response or throws [DiseaseApiException].
  Future<DiseaseInferenceResult> predictImage(dynamic image) async {
    final req = http.MultipartRequest('POST', _uri(ApiConfig.predictPath));
    Uint8List bytes;
    String filename;
    if (image is File) {
      bytes = await image.readAsBytes();
      filename = image.uri.pathSegments.isNotEmpty
          ? image.uri.pathSegments.last
          : 'leaf.jpg';
    } else if (image is Uint8List) {
      bytes = image;
      filename = 'leaf.jpg';
    } else {
      throw DiseaseApiException('unsupported image argument: ${image.runtimeType}');
    }
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    try {
      final streamed = await _client.send(req).timeout(ApiConfig.inferenceTimeout);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw DiseaseApiException(
          'predict failed: ${res.body}',
          statusCode: res.statusCode,
        );
      }
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      return DiseaseInferenceResult.fromJson(decoded);
    } on DiseaseApiException {
      rethrow;
    } catch (e) {
      throw DiseaseApiException('predict transport error: $e');
    }
  }

  void dispose() => _client.close();
}