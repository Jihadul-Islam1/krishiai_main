/// Centralised network configuration for the Krishi AI mobile app.
///
/// All endpoint URLs live here so we have a single switch to flip when
/// we move between local dev, staging, and production. The default
/// base URL is the deployed server on Render (ml_backend/deploy/).
///
/// Point at a local server with a `--dart-define` (10.0.2.2 is how the
/// Android emulator reaches the host machine's `localhost`):
///   flutter run --dart-define=KRISHI_API_BASE_URL=http://10.0.2.2:8000
library;

class ApiConfig {
  ApiConfig._();

  /// Where the FastAPI inference server lives.
  static const String baseUrl = String.fromEnvironment(
    'KRISHI_API_BASE_URL',
    defaultValue: 'https://krishiai-api-n0rk.onrender.com',
  );

  /// How long a `/predict` call may take end-to-end before we abort
  /// and tell the farmer the server is slow. Includes uploading the
  /// photo over a weak rural connection, and waking the free-tier
  /// server, which sleeps after 15 idle minutes and takes up to a
  /// minute to start.
  static const Duration inferenceTimeout = Duration(seconds: 90);

  /// How long `/health` may take; long enough to wake a sleeping server.
  static const Duration healthTimeout = Duration(seconds: 90);

  /// `/predict` accepts multipart `crop=<id>` + `file=<image>`; see
  /// `ml_backend/api/main.py` for the response contract.
  static const String predictPath = '/predict';

  /// `/health` tells the doctor screen whether the server is reachable
  /// and which crops have a model, before the farmer uploads a photo.
  static const String healthPath = '/health';
}