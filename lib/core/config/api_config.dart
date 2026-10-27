/// Centralised network configuration for the Krishi AI mobile app.
///
/// All endpoint URLs live here so we have a single switch to flip when
/// we move between local dev, staging, and production. The default
/// base URL targets the Android emulator loopback (10.0.2.2) — that
/// is how a Flutter app running inside an emulator reaches the host
/// machine's `localhost`.
///
/// Override at runtime with a `--dart-define`:
///   flutter run --dart-define=KRISHI_API_BASE_URL=http://192.168.0.42:8000
library;

class ApiConfig {
  ApiConfig._();

  /// Where the FastAPI inference server lives.
  static const String baseUrl = String.fromEnvironment(
    'KRISHI_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// How long a `/predict` call may take end-to-end before we abort
  /// and tell the farmer the server is slow. Includes uploading the
  /// photo over a weak rural connection.
  static const Duration inferenceTimeout = Duration(seconds: 25);

  /// `/predict` accepts multipart `crop=<id>` + `file=<image>`; see
  /// `ml_backend/api/main.py` for the response contract.
  static const String predictPath = '/predict';

  /// `/health` tells the doctor screen whether the server is reachable
  /// and which crops have a model, before the farmer uploads a photo.
  static const String healthPath = '/health';
}