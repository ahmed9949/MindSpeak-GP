import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class STTService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _speechToText.isListening;

  Future<void> initialize({
    required void Function(SpeechRecognitionError error)? onError,
    required void Function(String status)? onStatus,
  }) async {
    if (_isInitialized) return;
    _isInitialized = await _speechToText.initialize(
      onError: onError,
      onStatus: onStatus,
      debugLogging: false,
    );

    if (!_isInitialized) {
      throw Exception('Speech recognition not available on this device');
    }
  }

  Future<void> startListening({
    required void Function(
            String recognizedWords, double confidence, bool isFinal)
        onResult,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 5),
    bool partialResults = true,
    bool cancelOnError = true,
    ListenMode listenMode = ListenMode.dictation,
  }) async {
    if (!_isInitialized) {
      throw Exception('STT not initialized. Call initialize() first.');
    }

    await _speechToText.listen(
      onResult: (result) {
        onResult(
          result.recognizedWords,
          result.confidence,
          result.finalResult,
        );
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      partialResults: false, // no partial results
      cancelOnError: true,
      listenMode: listenMode,
    );
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }
}