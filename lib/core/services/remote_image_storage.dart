import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Abstract image uploader so the crop-doctor screen never knows which
/// provider is in use. Swap to Firebase Storage later by writing a new
/// `FirebaseImageStorage` that fulfils the same contract.
abstract class RemoteImageStorage {
  /// Uploads [bytes] and returns a stable public URL the Firestore doc can
  /// store. Implementations may throw [RemoteImageUploadException] on
  /// network / auth failure.
  Future<String> uploadBytes(
    List<int> bytes, {
    required String filename,
    String folder = 'krishiai',
  });
}

class RemoteImageUploadException implements Exception {
  RemoteImageUploadException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() =>
      'RemoteImageUploadException: $message'
      '${cause != null ? ' ($cause)' : ''}';
}

/// Cloudinary unsigned-upload implementation. The crop-doctor screen supplies
/// the local file's bytes; we POST them to the cloud's upload endpoint using
/// the `upload_preset` from the dashboard.
///
/// Required `.env` keys (filled by the maintainer — never commit real values):
///   CLOUDINARY_CLOUD_NAME      e.g. "krishiai"
///   CLOUDINARY_UPLOAD_PRESET   e.g. "krishiai_unsigned"
class CloudinaryImageStorage implements RemoteImageStorage {
  CloudinaryImageStorage({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _cloudName {
    final v = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (v == null || v.isEmpty) {
      throw RemoteImageUploadException(
        'CLOUDINARY_CLOUD_NAME missing in .env',
      );
    }
    return v;
  }

  String get _uploadPreset {
    final v = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    if (v == null || v.isEmpty) {
      throw RemoteImageUploadException(
        'CLOUDINARY_UPLOAD_PRESET missing in .env',
      );
    }
    return v;
  }

  @override
  Future<String> uploadBytes(
    List<int> bytes, {
    required String filename,
    String folder = 'krishiai',
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final digest = sha1.convert(bytes).toString().substring(0, 12);
    final publicId = '${DateTime.now().millisecondsSinceEpoch}_$digest';

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    try {
      final streamed = await _client.send(req).timeout(
            const Duration(seconds: 30),
          );
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode ~/ 100 != 2) {
        throw RemoteImageUploadException(
          'Cloudinary rejected upload (HTTP ${resp.statusCode}): ${resp.body}',
        );
      }
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) {
        throw RemoteImageUploadException(
          'Cloudinary returned a non-JSON body: ${resp.body}',
        );
      }
      final url = body['secure_url']?.toString() ?? body['url']?.toString() ?? '';
      if (url.isEmpty) {
        throw RemoteImageUploadException(
          'Cloudinary response missing secure_url: ${resp.body}',
        );
      }
      return url;
    } on SocketException catch (e) {
      throw RemoteImageUploadException('No network for Cloudinary upload', cause: e);
    } on TimeoutException catch (e) {
      throw RemoteImageUploadException('Cloudinary upload timed out', cause: e);
    } on http.ClientException catch (e) {
      throw RemoteImageUploadException('Cloudinary client error', cause: e);
    }
  }
}
