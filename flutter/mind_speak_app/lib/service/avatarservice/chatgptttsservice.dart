import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGptTtsService {
  final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
  String _voice = 'nova';
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
    "لحظة واحدة من فضلك",
    "أنا بفكر",
    "ثانية واحدة",
    "جاري التفكير "
  ];

  ChatGptTtsService({String? voice}) {
    // Set the voice if provided
    if (voice != null && voice.isNotEmpty) {
      _voice = voice;
    }

    // Configure the audio player properly - IMPORTANT
    _configureAudioPlayer().then((_) {
      print("🎤 TTS service audio player configured");
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      print("🎤 Audio playback completed");
      _isPlaying = false;
      _completionHandler?.call();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      print("🎤 Audio player state changed: $state");
      if (state == PlayerState.playing) {
        _startPlaybackHandler?.call();
      } else if (state == PlayerState.completed) {
        _isPlaying = false;
        _completionHandler?.call();
      } else if (state == PlayerState.stopped && _isPlaying) {
        // This might indicate an error or unexpected stop
        print("⚠️ Audio player stopped unexpectedly while _isPlaying=true");
        _isPlaying = false;
        _completionHandler?.call();
      }
    });
  }

// Add this configuration method
  Future<void> _configureAudioPlayer() async {
    try {
      // Use MediaPlayer mode which supports BytesSource
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      // Set release mode to stop to ensure resources are released
      _audioPlayer.setReleaseMode(ReleaseMode.stop);

      // Set volume to maximum
      _audioPlayer.setVolume(1.0);

      print("🔊 AudioPlayer configured in MediaPlayer mode");
    } catch (e) {
      print("⚠️ Error configuring AudioPlayer: $e");
      // Continue anyway
    }
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

  void forceResetState() {
    print("🔄 Forcing TTS service state reset");
    _isPlaying = false;
    _isSpeakingMain = false;
    _waitingPhraseIsPlaying = false;
    _isUsingWaitingPhrase = false;
    _mainTtsQueued = false;
    _queuedTtsAudio = null;
    _mainTtsRetryCount = 0;
    _waitingPhraseTimer?.cancel();
    _queuedTtsTimeoutTimer?.cancel();
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

  void setVoice(String voice) {
    if (_voice != voice) {
      print("🎤 Changing voice from $_voice to $voice");
      _voice = voice;

      // Clear the audio cache to ensure new voice is used
      _audioCache.clear();

      print("🎤 Voice changed, audio cache cleared");
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
          "voice": _voice, // This will now use the current voice value
          "speed": 1.1, // Slight speed boost
        }),
      );

      if (response.statusCode == 200) {
        _audioCache[text] = response.bodyBytes;
        print("✅ Pre-cached: \"$text\" with voice $_voice");
      } else {
        print("❌ Failed to cache \"$text\": ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error caching \"$text\": $e");
    }
  }

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
    print("⏳ Waiting phrase start signaled");

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
              print("⚠️ Playing queued TTS after timeout");
              _playQueuedTts();
            } else {
              // Important: reset the waiting phrase state
              _isUsingWaitingPhrase = false;
            }
            completer.complete();
          }
        });

        _completionHandler = () {
          waitingPhraseTimeout.cancel();
          print("⏳ Waiting phrase complete, handling next steps");
          _waitingPhraseIsPlaying = false;

          // Signal waiting phrase end for animation
          _waitingPhraseEndHandler?.call();
          print("⏳ Waiting phrase end signaled");

          // If we have queued TTS audio to play after this waiting phrase
          if (_mainTtsQueued && _queuedTtsAudio != null) {
            print("⏳ Found queued TTS, playing it now");
            // Shorter delay to ensure proper transition
            Future.delayed(const Duration(milliseconds: 50), () {
              if (_queuedTtsAudio != null) {
                _playQueuedTts();
              } else {
                print(
                    "⚠️ Queued TTS audio became null between check and playback");
                // Important: reset waiting phrase state
                _isUsingWaitingPhrase = false;
              }
            });
          } else {
            print("⏳ No queued TTS found after waiting phrase");
            // Important: reset waiting phrase state
            _isUsingWaitingPhrase = false;
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

        try {
          // Try in mediaPlayer mode to ensure BytesSource works
          await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
          await _audioPlayer.play(BytesSource(_audioCache[phrase]!));
          print("⏳ Waiting phrase audio playback started");
        } catch (e) {
          print("❌ Error playing waiting phrase audio: $e");
          // Force completion on error
          _waitingPhraseIsPlaying = false;
          _isUsingWaitingPhrase = false;
          _waitingPhraseEndHandler?.call();
          waitingPhraseTimeout.cancel();

          // Restore original handler
          _completionHandler = oldCompletionHandler;

          if (_mainTtsQueued && _queuedTtsAudio != null) {
            print(
                "⚠️ Error in waiting phrase, trying to play queued TTS anyway");
            Future.delayed(const Duration(milliseconds: 300), () {
              _playQueuedTts();
            });
          }

          if (!completer.isCompleted) completer.complete();
        }

        // Wait for completion (will be triggered by onPlayerComplete listener)
        return await completer.future;
      } else {
        // Fallback if somehow not cached - generate on the fly
        // ... (rest of the existing method for fallback scenario)
      }
    } catch (e) {
      print("❌ Error in playWaitingPhrase: $e");
      _waitingPhraseIsPlaying = false;
      _isUsingWaitingPhrase = false;
      _waitingPhraseEndHandler?.call();

      // If we have queued TTS, try to play it despite the error
      if (_mainTtsQueued && _queuedTtsAudio != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _playQueuedTts();
        });
      }
    }
  }

  Future<void> _playQueuedTts() async {
    try {
      print("▶️ Playing queued TTS audio (attempt: ${_mainTtsRetryCount + 1})");
      print(
          "▶️ Queue status: audio null? ${_queuedTtsAudio == null}, mainTtsQueued: $_mainTtsQueued");

      // Store a local copy to prevent null issues during async operations
      final audioToPlay = _queuedTtsAudio;

      _mainTtsQueued = false;
      _isSpeakingMain = true;

      // Cancel any previous timeout timer
      _queuedTtsTimeoutTimer?.cancel();

      // Signal main speech start for animation
      _mainSpeechStartHandler?.call();
      print("▶️ Main speech start signaled");

      if (audioToPlay != null) {
        // Set up a timeout in case the audio player gets stuck
        _queuedTtsTimeoutTimer = Timer(const Duration(seconds: 8), () {
          print("⚠️ TTS playback timeout - forcing completion");
          _completionHandler?.call();
          _queuedTtsAudio = null;
          _mainTtsRetryCount = 0;
          _isSpeakingMain = false;
        });

        try {
          // Ensure we're in mediaPlayer mode for BytesSource
          await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
          await _audioPlayer.play(BytesSource(audioToPlay));
          print("▶️ Queued TTS audio playback started successfully");
          _queuedTtsAudio = null;
          _mainTtsRetryCount = 0;
        } catch (e) {
          print("❌ Error in audio playback: $e");
          throw e; // Re-throw to trigger retry logic
        }
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
      print(
          "🔍 TTS SPEAK START - States: _isPlaying=$_isPlaying, _waitingPhraseIsPlaying=$_waitingPhraseIsPlaying, _mainTtsQueued=$_mainTtsQueued");

      await stop(); // stop current speech
      _isPlaying = true;
      _mainTtsQueued = false;
      _queuedTtsAudio = null;
      _mainTtsRetryCount = 0;

      print(
          "🎤 Speaking with voice $_voice: \"${text.substring(0, min(30, text.length))}...\" (isConversation: $isConversation)");

      // Start a timer to play waiting phrase if API takes too long
      if (isConversation && _isInConversation) {
        _waitingPhraseTimer?.cancel(); // Cancel any existing timer first
        _waitingPhraseTimer = Timer(const Duration(milliseconds: 800), () {
          if (_isPlaying && !_waitingPhraseIsPlaying) {
            print("⏳ API taking time, starting waiting phrase");
            playWaitingPhrase();
          }
        });
      }

      // Generate TTS
      try {
        final url = Uri.parse("https://api.openai.com/v1/audio/speech");
        print(
            "🎤 Sending TTS request with voice $_voice: \"${text.substring(0, min(30, text.length))}...\"");

        final response = await http.post(
          url,
          headers: {
            "Authorization": "Bearer $_apiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": _model,
            "input": text,
            "voice": _voice, // Uses current voice setting
          }),
        );

        _waitingPhraseTimer?.cancel();

        if (response.statusCode == 200) {
          if (!_isPlaying) {
            print("⚠️ TTS no longer active, discarding response");
            return;
          }

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
          _queuedTtsTimeoutTimer?.cancel();
          _queuedTtsTimeoutTimer = Timer(const Duration(seconds: 10), () {
            print("⚠️ TTS playback timeout - forcing completion");
            _completionHandler?.call();
            _isSpeakingMain = false;
          });

          print(
              "▶️ Starting TTS playback with voice $_voice (${audioBytes.length} bytes)");

          try {
            // Attempt to play, with extra error handling for BytesSource issues
            await _audioPlayer.play(BytesSource(audioBytes));
            print("▶️ TTS playback method completed successfully");
          } catch (playError) {
            print("❌ Error during audio playback: $playError");

            // If it's the BytesSource error in LOW_LATENCY mode, try switching modes temporarily
            if (playError
                .toString()
                .contains("Bytes sources are not supported")) {
              print("🔄 Attempting to switch audio player mode and retry");
              try {
                await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
                await _audioPlayer.play(BytesSource(audioBytes));
                print("✅ Successfully played audio after switching mode");
              } catch (retryError) {
                print("❌ Retry also failed: $retryError");
                throw retryError; // Re-throw to trigger completion handler
              }
            } else {
              throw playError; // Re-throw other errors
            }
          }
        } else {
          _isPlaying = false;
          throw Exception(
              'TTS error: ${response.statusCode} - ${response.body}');
        }
      } catch (apiError) {
        print("❌ TTS API error: $apiError");

        // Special handling for waiting phrase transition
        if (_waitingPhraseIsPlaying) {
          print(
              "⚠️ API error while waiting phrase is playing - forcing transition to idle");
          _waitingPhraseIsPlaying = false;
          _isUsingWaitingPhrase = false;
          _waitingPhraseEndHandler?.call();
        }

        _isPlaying = false;
        _isSpeakingMain = false;
        throw apiError; // Re-throw to trigger completion handler
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
    print("🛑 TTS stop called");
    _waitingPhraseTimer?.cancel();
    _queuedTtsTimeoutTimer?.cancel();
    _mainTtsQueued = false;
    _queuedTtsAudio = null;
    _isSpeakingMain = false;
    _mainTtsRetryCount = 0;
    _waitingPhraseIsPlaying = false;
    _isUsingWaitingPhrase = false;

    if (_isPlaying) {
      _isPlaying = false;
      try {
        await _audioPlayer.stop();
        print("🛑 AudioPlayer stopped successfully");
      } catch (e) {
        print("⚠️ Error stopping AudioPlayer: $e");
        // Continue anyway
      }
      _cancelHandler?.call();
    } else {
      print("🛑 TTS stop called but _isPlaying was already false");
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
