// lib/controllers/audio_controller.dart

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AudioController {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool isListening = false;
  bool isSpeaking = false;

  /// Initialize both TTS and STT.
  Future<void> init() async {
    // TTS initialization
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    // STT initialization
    bool available = await _speech.initialize(
      onStatus: (status) {
        // You may log status updates here if needed.
      },
      onError: (error) {
        // Handle STT errors if needed.
      },
    );
    if (!available) {
      throw Exception("Speech-to-Text is not available on this device.");
    }
  }

  /// Speak the given [text]. Stops TTS if already speaking.
  Future<void> speak(String text) async {
    if (isSpeaking) {
      await stopSpeaking();
    }
    isSpeaking = true;
    await _flutterTts.speak(text);
  }

  /// Stop any ongoing TTS.
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    isSpeaking = false;
  }

  /// Start listening for speech input.
  /// The [onResult] callback receives recognized text.
  Future<void> startListening({required Function(String) onResult}) async {
    if (isListening) {
      await stopListening();
    }
    isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: false,
      localeId: 'ar-EG',
    );
  }

  /// Stop listening.
  Future<void> stopListening() async {
    await _speech.stop();
    isListening = false;
  }

  /// Toggle listening mode.
  /// If TTS is active, it will stop before starting to listen.
  Future<void> toggleListening({required Function(String) onResult}) async {
    if (!isListening) {
      if (isSpeaking) {
        await stopSpeaking();
      }
      await startListening(onResult: onResult);
    } else {
      await stopListening();
    }
  }
}
