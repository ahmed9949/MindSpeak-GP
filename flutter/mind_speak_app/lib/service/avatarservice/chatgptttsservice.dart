import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGptTtsService {
  final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
  final String _voice = 'nova';
  final String _model = 'gpt-4o-mini-tts';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _audioCache = {}; // ✅ cache

  Function? _completionHandler;
  Function? _cancelHandler;
  Function? _startPlaybackHandler;
  bool _waitingPhraseIsPlaying = false;
  bool _mainTtsQueued = false;
  Uint8List? _queuedTtsAudio;

  bool _isPlaying = false;
  bool _isInConversation = false;
  bool _isUsingWaitingPhrase = false;
  Timer? _waitingPhraseTimer;
  // Add these flags to track state
  bool _isSpeakingMain = false;

  int _mainTtsRetryCount = 0;
  Timer? _queuedTtsTimeoutTimer;

  Function? _waitingPhraseStartHandler;
  Function? _waitingPhraseEndHandler;
  Function? _mainSpeechStartHandler;
  final List<String> _commonPhrases = [
    "برافو! أحسنت",
    "حاول تاني",
    "برافو! الإجابة صحيحة",
    "لا، حاول مرة أخرى"
  ];

  // Waiting phrases in Egyptian Arabic
  final List<String> _waitingPhrases = [
    "لحظة واحدة من فضلك...",
    "أنا بفكر...",
    "ثانية واحدة...",
    "جاري التفكير..."
  ];

  ChatGptTtsService() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _completionHandler?.call();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _startPlaybackHandler?.call();
      } else if (state == PlayerState.completed) {
        _isPlaying = false;
        _completionHandler?.call();
      }
    });
  }

  void setCompletionHandler(Function callback) {
    _completionHandler = callback;
  }

  void setWaitingPhraseStartHandler(Function callback) {
    _waitingPhraseStartHandler = callback;
  }

  void setWaitingPhraseEndHandler(Function callback) {
    _waitingPhraseEndHandler = callback;
  }

  void setMainSpeechStartHandler(Function callback) {
    _mainSpeechStartHandler = callback;
  }

  void setCancelHandler(Function callback) {
    _cancelHandler = callback;
  }

  void setStartPlaybackHandler(Function callback) {
    _startPlaybackHandler = callback;
  }

  // Method to enable/disable conversation mode
  void setConversationMode(bool inConversation) {
    _isInConversation = inConversation;
  }

  Future<void> initialize() async {
    print("🔄 Initializing TTS service...");

    // Cache common phrases
    for (final phrase in _commonPhrases) {
      await _prefetchAudio(phrase);
    }
    print("✅ Common TTS phrases preloaded");

    // Cache waiting phrases as well
    print("🔄 Preloading waiting phrases...");
    for (final phrase in _waitingPhrases) {
      await _prefetchAudio(phrase);
    }
    print("✅ Waiting phrases preloaded");
  }

  Future<void> prefetchDynamic(List<String> phrases) async {
    for (final phrase in phrases) {
      if (!_audioCache.containsKey(phrase)) {
        await _prefetchAudio(phrase);
      }
    }
  }

  Future<void> _prefetchAudio(String text) async {
    if (_audioCache.containsKey(text)) return;

    try {
      final url = Uri.parse("https://api.openai.com/v1/audio/speech");

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "input": text,
          "voice": _voice,
          "speed": 1.1, // Slight speed boost
        }),
      );

      if (response.statusCode == 200) {
        _audioCache[text] = response.bodyBytes;
        print("✅ Pre-cached: \"$text\"");
      } else {
        print("❌ Failed to cache \"$text\": ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error caching \"$text\": $e");
    }
  }

  /// Plays a random waiting phrase while the main TTS response is being generated.
  /// This method handles synchronization between waiting phrases and the main TTS.
  Future<void> playWaitingPhrase() async {
    // Skip if not in conversation mode, already using a waiting phrase, or a waiting phrase is already playing
    if (!_isInConversation ||
        _isUsingWaitingPhrase ||
        _waitingPhraseIsPlaying) {
      print(
          "⏳ Skipping waiting phrase - not in conversation or already playing");
      return;
    }

    _isUsingWaitingPhrase = true;
    _waitingPhraseIsPlaying = true;

    // Signal waiting phrase start for animation
    _waitingPhraseStartHandler?.call();

    // Select a random waiting phrase
    final random = Random();
    final phrase = _waitingPhrases[random.nextInt(_waitingPhrases.length)];

    try {
      print("⏳ Playing waiting phrase: \"$phrase\"");

      // Use cached version if available
      if (_audioCache.containsKey(phrase)) {
        final completer = Completer<void>();
        final oldCompletionHandler = _completionHandler;

        // Create a timeout for waiting phrase completion
        final waitingPhraseTimeout = Timer(const Duration(seconds: 5), () {
          print("⚠️ Waiting phrase timeout - forcing completion");
          if (!completer.isCompleted) {
            _waitingPhraseIsPlaying = false;
            _waitingPhraseEndHandler?.call();

            // Force play queued TTS if it exists
            if (_mainTtsQueued && _queuedTtsAudio != null) {
              _playQueuedTts();
            }

            completer.complete();
          }
        });

        _completionHandler = () {
          print("⏳ Waiting phrase complete, handling next steps");
          _waitingPhraseIsPlaying = false;

          // Cancel timeout
          waitingPhraseTimeout.cancel();

          // Signal waiting phrase end for animation
          _waitingPhraseEndHandler?.call();

          // If we have queued TTS audio to play after this waiting phrase
          if (_mainTtsQueued && _queuedTtsAudio != null) {
            print("⏳ Found queued TTS, playing it now");
            // Short delay to ensure proper transition
            Future.delayed(const Duration(milliseconds: 100), () {
              _playQueuedTts();
            });
          } else {
            print("⏳ No queued TTS found after waiting phrase");
          }

          // Restore original completion handler
          _completionHandler = oldCompletionHandler;

          // Call the original handler if it exists
          if (oldCompletionHandler != null) {
            oldCompletionHandler();
          }

          // Complete this operation
          if (!completer.isCompleted) completer.complete();
        };

        await _audioPlayer.play(BytesSource(_audioCache[phrase]!));

        // Wait for completion (will be triggered by onPlayerComplete listener)
        return await completer.future;
      } else {
        // Fallback if somehow not cached - generate on the fly
        print("⚠️ Waiting phrase not cached, generating on the fly");
        final url = Uri.parse("https://api.openai.com/v1/audio/speech");

        final response = await http.post(
          url,
          headers: {
            "Authorization": "Bearer $_apiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": _model,
            "input": phrase,
            "voice": _voice,
            "speed": 1.2, // Slightly faster for waiting phrases
          }),
        );

        if (response.statusCode == 200) {
          // Cache for future use
          _audioCache[phrase] = response.bodyBytes;

          // Create a completer to properly handle async completion
          final completer = Completer<void>();

          // Save the original completion handler
          final oldCompletionHandler = _completionHandler;

          // Set a temporary completion handler
          _completionHandler = () {
            print(
                "⏳ Waiting phrase complete (from fallback), handling next steps");
            _waitingPhraseIsPlaying = false;

            // If we have queued TTS audio to play after this waiting phrase
            if (_mainTtsQueued && _queuedTtsAudio != null) {
              print("⏳ Found queued TTS, playing it now");
              _playQueuedTts();
            }

            // Restore original completion handler
            _completionHandler = oldCompletionHandler;

            // Call the original handler if it exists
            if (oldCompletionHandler != null) {
              oldCompletionHandler();
            }

            // Complete this operation
            if (!completer.isCompleted) completer.complete();
          };

          // Play the waiting phrase
          await _audioPlayer.play(BytesSource(response.bodyBytes));

          // Wait for completion
          return await completer.future;
        } else {
          throw Exception(
              'Error generating waiting phrase: ${response.statusCode}');
        }
      }
    } catch (e) {
      print("❌ Error playing waiting phrase: $e");
      _waitingPhraseIsPlaying = false;
      _waitingPhraseEndHandler?.call();

      // If we have queued TTS, try to play it despite the error
      if (_mainTtsQueued && _queuedTtsAudio != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _playQueuedTts();
        });
      }
    } finally {
      if (!_waitingPhraseIsPlaying) {
        _isUsingWaitingPhrase = false;
      }
    }
  }

  Future<void> _playQueuedTts() async {
    try {
      print("▶️ Playing queued TTS audio (attempt: ${_mainTtsRetryCount + 1})");
      _mainTtsQueued = false;
      _isSpeakingMain = true;

      // Cancel any previous timeout timer
      _queuedTtsTimeoutTimer?.cancel();

      // Signal main speech start for animation
      _mainSpeechStartHandler?.call();

      if (_queuedTtsAudio != null) {
        // Set up a timeout in case the audio player gets stuck
        _queuedTtsTimeoutTimer = Timer(const Duration(seconds: 8), () {
          print("⚠️ TTS playback timeout - forcing completion");
          _completionHandler?.call();
          _queuedTtsAudio = null;
          _mainTtsRetryCount = 0;
          _isSpeakingMain = false;
        });

        await _audioPlayer.play(BytesSource(_queuedTtsAudio!));
        _queuedTtsAudio = null;
        _mainTtsRetryCount = 0;
      } else {
        print("⚠️ No queued TTS audio found");
        _isSpeakingMain = false;
        _completionHandler?.call();
      }
    } catch (e) {
      print("❌ Error playing queued TTS: $e");

      // Retry logic for queued TTS
      if (_mainTtsRetryCount < 2 && _queuedTtsAudio != null) {
        _mainTtsRetryCount++;
        print(
            "🔄 Retrying queued TTS playback (attempt ${_mainTtsRetryCount})");
        await Future.delayed(const Duration(milliseconds: 500));
        _playQueuedTts();
      } else {
        // Give up after retries
        print("❌ Failed to play queued TTS after retries");
        _isSpeakingMain = false;
        _isPlaying = false;
        _queuedTtsAudio = null;
        _mainTtsRetryCount = 0;
        _completionHandler?.call();
      }
    }
  }

  Future<void> speak(String text, {bool isConversation = false}) async {
    try {
      await stop(); // stop current speech
      _isPlaying = true;
      _mainTtsQueued = false;
      _queuedTtsAudio = null;
      _mainTtsRetryCount = 0;

      print(
          "🎤 Speaking: \"${text.substring(0, min(30, text.length))}...\" (isConversation: $isConversation)");

      // Start a timer to play waiting phrase if API takes too long
      if (isConversation && _isInConversation) {
        _waitingPhraseTimer = Timer(const Duration(milliseconds: 800), () {
          playWaitingPhrase();
        });
      }

      if (_audioCache.containsKey(text)) {
        print(
            "▶️ Found in cache: \"${text.substring(0, min(30, text.length))}...\"");
        _waitingPhraseTimer?.cancel();

        // If a waiting phrase is currently playing, queue this for after
        if (_waitingPhraseIsPlaying) {
          print("⏳ Waiting phrase is playing, queuing main TTS");
          _mainTtsQueued = true;
          _queuedTtsAudio = _audioCache[text]!;
          return;
        }

        // Signal main speech start
        _isSpeakingMain = true;
        _mainSpeechStartHandler?.call();

        // Set up a timeout in case the audio player gets stuck
        _queuedTtsTimeoutTimer = Timer(const Duration(seconds: 10), () {
          print("⚠️ TTS playback timeout - forcing completion");
          _completionHandler?.call();
          _isSpeakingMain = false;
        });

        await _audioPlayer.play(BytesSource(_audioCache[text]!));
        return;
      }

      // Generate TTS
      final url = Uri.parse("https://api.openai.com/v1/audio/speech");
      print(
          "🎤 Sending TTS request: \"${text.substring(0, min(30, text.length))}...\"");

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "input": text,
          "voice": _voice,
        }),
      );

      _waitingPhraseTimer?.cancel();

      if (response.statusCode == 200) {
        if (!_isPlaying) return;
        print(
            "✅ TTS API response received (${response.bodyBytes.length} bytes)");

        Uint8List audioBytes = response.bodyBytes;
        _audioCache[text] = audioBytes;

        // If a waiting phrase is currently playing, queue this for after
        if (_waitingPhraseIsPlaying) {
          print("⏳ Waiting phrase is playing, queuing main TTS");
          _mainTtsQueued = true;
          _queuedTtsAudio = audioBytes;
          return;
        }

        // Signal main speech start
        _isSpeakingMain = true;
        _mainSpeechStartHandler?.call();

        // Set up a timeout in case the audio player gets stuck
        _queuedTtsTimeoutTimer = Timer(const Duration(seconds: 10), () {
          print("⚠️ TTS playback timeout - forcing completion");
          _completionHandler?.call();
          _isSpeakingMain = false;
        });

        print("▶️ Starting TTS playback (${audioBytes.length} bytes)");
        await _audioPlayer.play(BytesSource(audioBytes));
        print("▶️ TTS playback method completed");
      } else {
        _isPlaying = false;
        throw Exception('TTS error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("❌ TTS speak error: $e");
      _isPlaying = false;
      _isSpeakingMain = false;
      _waitingPhraseTimer?.cancel();
      _completionHandler?.call(); // Ensure completion is called even on error
    }
  }
  Future<void> stop() async {
    _waitingPhraseTimer?.cancel();
    _queuedTtsTimeoutTimer?.cancel();
    _mainTtsQueued = false;
    _queuedTtsAudio = null;
    _isSpeakingMain = false;
    _mainTtsRetryCount = 0;
    
    if (_isPlaying) {
      _isPlaying = false;
      await _audioPlayer.stop();
      _cancelHandler?.call();
    }
  }
  
  void dispose() {
    _waitingPhraseTimer?.cancel();
    _queuedTtsTimeoutTimer?.cancel();
    _audioPlayer.dispose();
  }
  // Getter to check if main speech is active
  bool get isMainSpeechActive => _isSpeakingMain;
  bool get isPlaying => _isPlaying;

 
}
