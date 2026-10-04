import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) => debugPrintSafe('Speech error: $e'),
      onStatus: (s) => debugPrintSafe('Speech status: $s'),
    );
    return _initialized;
  }

  Future<void> listen({
    required void Function(String text, bool finalResult) onResult,
    String localeId = 'bn_BD',
  }) async {
    final ready = await ensureInitialized();
    if (!ready) return;
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) =>
          onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: localeId,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  bool get listening => _speech.isListening;

  /// Lightweight console print so this service can run in tests too.
  void debugPrintSafe(String _) {}
}
