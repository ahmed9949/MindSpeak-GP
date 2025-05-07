import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class FlutterTtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  bool _isInitialized = false;

  // Callback functions
  Function? _completionHandler;
  Function? _cancelHandler;
  Function? _startPlaybackHandler;
  Function? _audioReadyHandler;

  FlutterTtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // Initialize with optimal settings for Arabic
      await _flutterTts.setLanguage('ar-EG');
      await _flutterTts.setSpeechRate(1.1);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up event listeners
      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
        _completionHandler?.call();
        print("✅ TTS completed");
      });

      _flutterTts.setCancelHandler(() {
        _isPlaying = false;
        _cancelHandler?.call();
        print("⏹️ TTS canceled");
      });

      _flutterTts.setStartHandler(() {
        _isPlaying = true;
        _startPlaybackHandler?.call();
        print("▶️ TTS started playback");
      });

      _isInitialized = true;
      print("✅ Flutter TTS initialized");
    } catch (e) {
      print("❌ TTS initialization error: $e");
    }
  }

  void setCompletionHandler(Function callback) {
    _completionHandler = callback;
  }

  void setCancelHandler(Function callback) {
    _cancelHandler = callback;
  }

  void setStartPlaybackHandler(Function callback) {
    _startPlaybackHandler = callback;
  }

  // For compatibility with ChatGptTtsService
  void setAudioReadyHandler(Function callback) {
    _audioReadyHandler = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    print("🔄 Initializing Flutter TTS service...");
    await _initTts();

    // Prewarm TTS engine with a silent speak
    try {
      await _flutterTts.speak(" ");
      await Future.delayed(const Duration(milliseconds: 100));
      await _flutterTts.stop();
    } catch (e) {
      print("⚠️ Prewarm speak failed: $e");
    }

    print("✅ Flutter TTS service ready");
  }

  Future<void> prefetchDynamic(List<String> phrases) async {
    // No actual prefetching in Flutter TTS, but we can prewarm the engine
    if (phrases.isNotEmpty) {
      print("✅ Simulating prefetch for ${phrases.length} phrases");
    }
    return Future.value();
  }

  Future<void> speak(String text) async {
    try {
      // Ensure we're initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Stop any current speech
      await stop();

      // CRITICAL CHANGE: Call audioReadyHandler BEFORE attempting to speak
      // This ensures animation starts before TTS has latency
      print("🔈 Audio ready event triggered");
      _audioReadyHandler?.call();

      // Small delay to ensure animation starts first
      await Future.delayed(const Duration(milliseconds: 50));

      // Set playing state
      _isPlaying = true;

      print(
          "🎤 Speaking: \"${text.substring(0, text.length > 30 ? 30 : text.length)}...\"");

      // Start speaking
      await _flutterTts.speak(text);
    } catch (e) {
      _isPlaying = false;
      print("❌ TTS speak error: $e");
    }
  }

  Future<void> stop() async {
    if (_isPlaying) {
      _isPlaying = false;
      await _flutterTts.stop();
      _cancelHandler?.call();
    }
  }

  bool get isPlaying => _isPlaying;
}
