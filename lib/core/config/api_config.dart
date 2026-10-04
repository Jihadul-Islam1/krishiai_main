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
  /// and fall back to the offline library advisor.
  static const Duration inferenceTimeout = Duration(seconds: 12);

  /// `/predict` accepts multipart `file=<image>`.
  static const String predictPath = '/predict';

  /// `/health` is used by the doctor screen to surface "backend
  /// offline" hints before the user picks a photo.
  static const String healthPath = '/health';
}