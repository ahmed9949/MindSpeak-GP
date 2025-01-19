import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  final StreamController<bool> _isListeningController = StreamController<bool>.broadcast();
  Stream<bool> get isListeningStream => _isListeningController.stream;
  bool get isListening => _isListening;

  Future<bool> initialize({
    required Function(SpeechRecognitionError) onError,
    required Function(String) onStatus,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          print('Speech error: ${error.errorMsg}'); // Debug log
          onError(error);
        },
        onStatus: (status) {
          print('Speech status: $status'); // Debug log
          onStatus(status);

          // Update listening state based on status
          if (status == 'listening') {
            _isListening = true;
            _isListeningController.add(true);
          } else if (status == 'notListening') {
            _isListening = false;
            _isListeningController.add(false);
          }
        },
        debugLogging: true, // Enable detailed logs for debugging
      );

      if (!_isInitialized) {
        print("Speech-to-Text initialization failed.");
      }

      return _isInitialized;
    } catch (e) {
      print('Error initializing Speech-to-Text: $e');
      return false;
    }
  }

  Future<void> startListening({
    required Function(SpeechRecognitionResult) onResult,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!_isInitialized) {
      throw Exception('Speech service not initialized');
    }

    if (!await _speechToText.hasPermission) {
      throw Exception('Speech recognition permission not granted');
    }

    try {
      _isListening = true;
      _isListeningController.add(true);

      await _speechToText.listen(
        onResult: (result) {
          print('Speech result: ${result.recognizedWords}'); // Debug log
          onResult(result);
        },
        listenMode: ListenMode.dictation,
        pauseFor: pauseFor,
        listenFor: listenFor,
        partialResults: true,
        cancelOnError: true,
        onSoundLevelChange: (level) {
          print('Sound level: $level'); // Debug log
        },
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
      _isListeningController.add(false);
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      _isListeningController.add(false);
    } catch (e) {
      print('Error stopping speech recognition: $e'); // Debug log
      rethrow;
    }
  }

  void dispose() {
    _isListeningController.close();
  }
}
