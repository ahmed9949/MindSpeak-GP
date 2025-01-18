import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  
  Future<bool> initialize({
    required Function(SpeechRecognitionError) onError,
    required Function(String) onStatus,
  }) async {
    if (_isInitialized) return true;
    
    _isInitialized = await _speechToText.initialize(
      onError: onError,
      onStatus: onStatus,
      debugLogging: true,
    );
    
    return _isInitialized;
  }
  
  Future<void> startListening({
    required Function(SpeechRecognitionResult) onResult,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {
    if (!_isInitialized) throw Exception('Speech service not initialized');
    
    await _speechToText.listen(
      onResult: onResult,
      listenMode: ListenMode.dictation,
      pauseFor: pauseFor,
      listenFor: listenFor,
      partialResults: true,
      cancelOnError: false,
    );
  }
  
  Future<void> stop() async {
    await _speechToText.stop();
  }
}
