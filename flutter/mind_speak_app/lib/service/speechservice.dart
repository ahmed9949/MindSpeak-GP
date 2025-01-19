import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

//   Future<bool> initialize({
//     required Function(SpeechRecognitionError) onError,
//     required Function(String) onStatus,
//   }) async {
//     if (_isInitialized) return true;

    try {
      // Force cleanup of any existing instance
      await _speechToText.cancel();
      await Future.delayed(const Duration(milliseconds: 500));

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          onError(error);
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          onStatus(status);
          if (status == 'notListening') {
            _isListening = false;
          }
        },
        debugLogging: kDebugMode,
      );

      return _isInitialized;
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      rethrow;
    }
  }

  Future<void> startListening({
    required Function(SpeechRecognitionResult) onResult,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {
    if (!_isInitialized) {
      throw Exception('Speech service not initialized');
    }

    if (_isListening) {
      await stop();
    }

    try {
      _isListening = true;
      await _speechToText.listen(
        onResult: onResult,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        onSoundLevelChange: (level) {
          debugPrint('Sound level: $level');
        },
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      _isListening = false;
      debugPrint('Error in startListening: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      _isListening = false;
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
  }

  bool get isListening => _isListening;

  bool get isAvailable => _isInitialized;
}