import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// An uploaded image: [url] is what the app displays, [deleteUrl] (when the
/// provider gives one) lets the owner remove it later.
class RemoteImage {
  const RemoteImage({required this.url, this.deleteUrl});
  final String url;
  final String? deleteUrl;
}

/// Abstract image uploader so screens never know which provider is in use.
abstract class RemoteImageStorage {
  /// Uploads [bytes] and returns the public image. [name] is a descriptive
  /// file name (the caller includes the owner's phone digits in it).
  /// Throws [RemoteImageUploadException] on network / auth failure.
  Future<RemoteImage> upload(List<int> bytes, {required String name});
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

/// ImgBB implementation (https://api.imgbb.com).
///
/// Required `.env` key:
///   IMGBB_API_KEY   from https://api.imgbb.com
///
/// ImgBB has no folders, so ownership is tracked in Firestore
/// (`users/{phone}/photos/{id}`) - see `user_photo_upload.dart`.
class ImgbbImageStorage implements RemoteImageStorage {
  ImgbbImageStorage({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String get _apiKey {
    final v = dotenv.env['IMGBB_API_KEY'];
    if (v == null || v.isEmpty) {
      throw RemoteImageUploadException('IMGBB_API_KEY missing in .env');
    }
    return v;
  }

  @override
  Future<RemoteImage> upload(List<int> bytes, {required String name}) async {
    final uri = Uri.https('api.imgbb.com', '/1/upload', {'key': _apiKey});
    final req = http.MultipartRequest('POST', uri)
      ..fields['name'] = name
      ..files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: '$name.jpg'),
      );

    try {
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 40));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode ~/ 100 != 2) {
        throw RemoteImageUploadException(
          'ImgBB rejected upload (HTTP ${resp.statusCode}): ${resp.body}',
        );
      }
      final body = jsonDecode(resp.body);
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final url = data is Map
          ? (data['display_url'] ?? data['url'])?.toString() ?? ''
          : '';
      if (url.isEmpty) {
        throw RemoteImageUploadException(
          'ImgBB response missing image url: ${resp.body}',
        );
      }
      return RemoteImage(
        url: url,
        deleteUrl: (data as Map)['delete_url']?.toString(),
      );
    } on SocketException catch (e) {
      throw RemoteImageUploadException('No network for image upload', cause: e);
    } on TimeoutException catch (e) {
      throw RemoteImageUploadException('Image upload timed out', cause: e);
    } on http.ClientException catch (e) {
      throw RemoteImageUploadException('Image upload client error', cause: e);
    }
  }
}
