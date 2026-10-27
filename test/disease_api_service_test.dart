import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:krishiai/core/network/disease_api_service.dart';

/// A real `/predict` response from `ml_backend/api/main.py` (tomato).
/// FastAPI sends `application/json` without a charset, so the client must
/// decode the Bangla as UTF-8 itself.
const _tomatoResponse = '{"crop":"tomato","model_version":"tomato-test",'
    '"inference_ms":0,"top_k":['
    '{"label":"late_blight","label_bn":"নাবী ধসা রোগ","label_en":"Late Blight","confidence":0.71,"severity":"medium"},'
    '{"label":"early_blight","label_bn":"আগাম ধসা রোগ","label_en":"Early Blight","confidence":0.12,"severity":"medium"},'
    '{"label":"healthy","label_bn":"সুস্থ টমেটো গাছ","label_en":"Healthy","confidence":0.1,"severity":"medium"}],'
    '"is_confident":true,"probable":true,"advisory":{},"note_bn":"এটি এআই-এর প্রাথমিক পরামর্শ"}';

final _image = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

void main() {
  test('predictImage sends the crop and parses the server verdict', () async {
    late http.Request sent;
    final api = DiseaseApiService(
      client: MockClient((req) async {
        sent = req;
        return http.Response.bytes(utf8.encode(_tomatoResponse), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final result = await api.predictImage(_image, crop: 'tomato');

    expect(sent.url.path, '/predict');
    final body = utf8.decode(sent.bodyBytes, allowMalformed: true);
    expect(body, contains('name="crop"\r\n\r\ntomato'));
    expect(body, contains('name="file"; filename="leaf.jpg"'));

    final prediction = result.toScanPrediction();
    expect(prediction.top.label, 'late_blight');
    expect(prediction.top.score, 0.71);
    expect(prediction.top.nameBn, 'নাবী ধসা রোগ');
    expect(prediction.ranked.map((s) => s.label),
        ['late_blight', 'early_blight', 'healthy']);
    expect(prediction.isConfident, isTrue);
    expect(prediction.isProbable, isTrue);
  });

  test('a response without a verdict leaves the call to the app', () async {
    final api = DiseaseApiService(
      client: MockClient((_) async => http.Response(
          '{"top_k":[{"label":"healthy","confidence":0.9}]}', 200)),
    );
    final prediction = (await api.predictImage(_image)).toScanPrediction();
    expect(prediction.isConfident, isNull);
    expect(prediction.isProbable, isNull);
  });

  Future<DiseaseApiErrorKind> kindOf(MockClientHandler handler) async {
    final api = DiseaseApiService(client: MockClient(handler));
    try {
      await api.predictImage(_image, crop: 'potato');
    } on DiseaseApiException catch (e) {
      return e.kind;
    }
    fail('expected a DiseaseApiException');
  }

  test('errors are classified for the UI', () async {
    expect(
      await kindOf((_) async => http.Response('{"detail":"no model"}', 503)),
      DiseaseApiErrorKind.modelUnavailable,
    );
    expect(
      await kindOf((_) async => http.Response('boom', 500)),
      DiseaseApiErrorKind.server,
    );
    expect(
      await kindOf((_) async => http.Response('not json', 200)),
      DiseaseApiErrorKind.badResponse,
    );
    expect(
      await kindOf((_) async => http.Response('{"top_k":[]}', 200)),
      DiseaseApiErrorKind.badResponse,
    );
    expect(
      await kindOf((_) => throw http.ClientException('Connection refused')),
      DiseaseApiErrorKind.network,
    );
  });

  test('health reports which crops have a model', () async {
    final up = DiseaseApiService(
      client: MockClient((_) async => http.Response(
          '{"status":"ok","uptime_s":1,"crops":{"potato":false,"tomato":true}}',
          200)),
    );
    final health = await up.health();
    expect(health, isNotNull);
    expect(health!.isReady('tomato'), isTrue);
    expect(health.isReady('potato'), isFalse);

    final down = DiseaseApiService(
      client: MockClient((_) => throw http.ClientException('offline')),
    );
    expect(await down.health(), isNull);
  });
}
