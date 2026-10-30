import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/scan_prediction.dart';

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
    this.hasVerdict = true,
  });

  final List<DiseasePrediction> topK;
  final bool isConfident;
  final bool probable;
  final Map<String, dynamic> advisory;
  final String noteBn;
  final String modelVersion;
  final int inferenceMs;

  /// Whether the server sent `is_confident` / `probable` (its own
  /// per-model thresholds) rather than leaving the call to the app.
  final bool hasVerdict;

  DiseasePrediction get top1 => topK.first;

  ScanPrediction toScanPrediction() => ScanPrediction(
    [
      for (final p in topK)
        LabelScore(p.label, p.confidence, nameBn: p.labelBn),
    ],
    isConfident: hasVerdict ? isConfident : null,
    isProbable: hasVerdict ? probable : null,
  );

  factory DiseaseInferenceResult.fromJson(Map<String, dynamic> json) {
    final list = (json['top_k'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiseasePrediction.fromJson)
        .toList();
    return DiseaseInferenceResult(
      topK: list,
      isConfident: json['is_confident'] as bool? ?? false,
      probable: json['probable'] as bool? ?? false,
      hasVerdict: json['is_confident'] is bool,
      advisory: (json['advisory'] as Map?)?.cast<String, dynamic>() ?? const {},
      noteBn: json['note_bn'] as String? ?? '',
      modelVersion: json['model_version'] as String? ?? 'unknown',
      inferenceMs: (json['inference_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What went wrong talking to the server, so the UI can say it in Bangla.
enum DiseaseApiErrorKind {
  /// No internet, DNS failure, or the server refused the connection.
  network,

  /// The server took longer than [ApiConfig.inferenceTimeout].
  timeout,

  /// The server is up but has no model for the requested crop (HTTP 503).
  modelUnavailable,

  /// Any other non-2xx response.
  server,

  /// 2xx but the body wasn't the expected JSON.
  badResponse,
}

/// Thrown when the backend is unreachable or returns a non-2xx
/// response. The Crop Doctor UI catches this and explains the [kind].
class DiseaseApiException implements Exception {
  DiseaseApiException(
    this.message, {
    this.statusCode,
    this.kind = DiseaseApiErrorKind.server,
  });

  final String message;
  final int? statusCode;
  final DiseaseApiErrorKind kind;

  @override
  String toString() => 'DiseaseApiException($kind, $statusCode): $message';
}

/// `/health` summary: which crops currently have a model on the server.
@immutable
class ServerHealth {
  const ServerHealth({this.crops});

  /// Crop id → model ready. Null when the server doesn't report it.
  final Map<String, bool>? crops;

  bool isReady(String crop) => crops?[crop] ?? true;
}

/// HTTP client wrapper that talks to the FastAPI `/predict` endpoint.
class DiseaseApiService {
  DiseaseApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Lightweight ping. Returns `true` if the server responds 2xx.
  Future<bool> ping() async => await health() != null;

  /// Reads `/health`. Returns null when the server can't be reached.
  Future<ServerHealth?> health() async {
    try {
      final r = await _client
          .get(_uri(ApiConfig.healthPath))
          .timeout(ApiConfig.healthTimeout);
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      final body = json.decode(r.body);
      final crops = body is Map && body['crops'] is Map
          ? (body['crops'] as Map).map((k, v) => MapEntry('$k', v == true))
          : null;
      return ServerHealth(crops: crops);
    } catch (_) {
      return null;
    }
  }

  /// Posts an image to `/predict`. Accepts either a `File` (mobile)
  /// or raw bytes (tests / web). [crop] picks the server-side model
  /// (`potato`, `tomato`, ...). Returns the parsed inference response
  /// or throws [DiseaseApiException].
  Future<DiseaseInferenceResult> predictImage(
    dynamic image, {
    String? crop,
  }) async {
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
      throw DiseaseApiException(
        'unsupported image argument: ${image.runtimeType}',
      );
    }
    if (crop != null) req.fields['crop'] = crop;
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    try {
      final streamed = await _client
          .send(req)
          .timeout(ApiConfig.inferenceTimeout);
      final res = await http.Response.fromStream(
        streamed,
      ).timeout(ApiConfig.inferenceTimeout);
      if (res.statusCode == 503) {
        throw DiseaseApiException(
          'model unavailable: ${res.body}',
          statusCode: res.statusCode,
          kind: DiseaseApiErrorKind.modelUnavailable,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw DiseaseApiException(
          'predict failed: ${res.body}',
          statusCode: res.statusCode,
        );
      }
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw DiseaseApiException(
          'unexpected body: ${res.body}',
          kind: DiseaseApiErrorKind.badResponse,
        );
      }
      final result = DiseaseInferenceResult.fromJson(decoded);
      if (result.topK.isEmpty) {
        throw DiseaseApiException(
          'empty top_k',
          kind: DiseaseApiErrorKind.badResponse,
        );
      }
      return result;
    } on DiseaseApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw DiseaseApiException(
        'predict timed out: $e',
        kind: DiseaseApiErrorKind.timeout,
      );
    } on FormatException catch (e) {
      throw DiseaseApiException(
        'predict returned invalid JSON: $e',
        kind: DiseaseApiErrorKind.badResponse,
      );
    } catch (e) {
      // SocketException, http.ClientException, handshake errors, ...
      throw DiseaseApiException(
        'predict transport error: $e',
        kind: DiseaseApiErrorKind.network,
      );
    }
  }

  void dispose() => _client.close();
}
