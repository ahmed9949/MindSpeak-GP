// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ChatGptTtsService {
//   final String _apiKey;
//   final String _voice;
//   final String _model;

//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final AudioPlayer _thinkingAudioPlayer = AudioPlayer();
//   final Map<String, Uint8List> _audioCache = {};

//   // Rate limiting variables
//   final Duration _minRequestInterval = Duration(milliseconds: 300);
//   DateTime _lastRequestTime = DateTime.now().subtract(Duration(seconds: 10));

//   // Retry configuration
//   final int _maxRetries = 2; // Reduced to avoid excessive retries

//   Function? _completionHandler;
//   Function? _cancelHandler;
//   Function? _startPlaybackHandler;
//   Function? _audioReadyHandler;
//   Function? _preparingAudioHandler;

//   bool _isPlaying = false;
//   bool _isPreparingAudio = false;
//   bool _isPlayingFillerPhrase = false;
//   bool _isWelcomeOrEndingMessage = false;

//   // Flag to prevent playing multiple thinking phrases
//   bool _thinkingPhraseAlreadyPlayed = false;

//   // Flag to prevent duplicate error messages
//   bool _errorMessageShown = false;

//   Timer? _thinkingPhraseChainTimer;

//   // List of messages that are considered welcome or ending
//   final List<String> _welcomeOrEndingPhrases = [
//     "مرحبا!",
//     "أهلاً",
//     "مرحباً",
//     "السلام عليكم",
//     "الى اللقاء",
//     "إلى اللقاء",
//     "وداعاً",
//     "مع السلامة",
//   ];

//   // Very minimal list of essential phrases to cache
//   final List<String> _priorityPhrases = [
//     "برافو! أحسنت",
//     "حاول تاني",
//     "هممم دعني أفكر...",
//     "لحظة واحدة...",
//     // "عذراً، حدث خطأ أثناء المعالجة."
//   ];

//   // Thinking phrases with placeholders for child's name - SIMPLIFIED
//   final List<String> _thinkingPhrases = [
//     "هممم دعني أفكر...",
//     "لحظة واحدة...",
//     "طيب...",
//   ];

//   ChatGptTtsService(
//       {String? apiKey, String voice = 'nova', String model = 'gpt-4o-mini-tts'})
//       : _apiKey = apiKey ?? dotenv.env['OPEN_AI_API_KEY'] ?? '',
//         _voice = voice,
//         _model = model {
//     // Main audio player completion listener
//     _audioPlayer.onPlayerComplete.listen((_) {
//       print("✅ Main audio playback completed");
//       _isPlaying = false;
//       _isWelcomeOrEndingMessage = false;
//       _errorMessageShown = false;

//       if (_completionHandler != null) {
//         _completionHandler!();
//       }
//     });

//     // Main audio player state change listener
//     _audioPlayer.onPlayerStateChanged.listen((state) {
//       if (state == PlayerState.playing) {
//         if (_startPlaybackHandler != null) {
//           _startPlaybackHandler!();
//         }
//       } else if (state == PlayerState.completed) {
//         _isPlaying = false;
//         _isWelcomeOrEndingMessage = false;
//         _errorMessageShown = false;

//         if (_completionHandler != null) {
//           _completionHandler!();
//         }
//       }
//     });

//     // Thinking audio player state change listener
//     _thinkingAudioPlayer.onPlayerComplete.listen((_) {
//       print("✅ Thinking phrase completed");
//       _isPlayingFillerPhrase = false;

//       // Don't chain multiple thinking phrases - this is what's causing multiple plays
//       // Instead, mark that we've already played one
//       _thinkingPhraseAlreadyPlayed = true;
//     });
//   }

//   void setCompletionHandler(Function callback) {
//     _completionHandler = callback;
//   }

//   void setCancelHandler(Function callback) {
//     _cancelHandler = callback;
//   }

//   void setStartPlaybackHandler(Function callback) {
//     _startPlaybackHandler = callback;
//   }

//   void setAudioReadyHandler(Function callback) {
//     _audioReadyHandler = callback;
//   }

//   void setPreparingAudioHandler(Function callback) {
//     _preparingAudioHandler = callback;
//   }

//   // Check if a phrase is a welcome or ending message
//   bool _isWelcomeOrEnding(String text) {
//     String lowerText = text.toLowerCase();

//     // Check if the text starts with any welcome or ending phrase
//     for (final phrase in _welcomeOrEndingPhrases) {
//       if (lowerText.startsWith(phrase.toLowerCase())) {
//         return true;
//       }
//     }

//     // Additional checks based on content patterns
//     if (lowerText.contains("كيف حالك") && lowerText.contains("مرحبا")) {
//       return true;
//     }

//     if (lowerText.contains("الى اللقاء") || lowerText.contains("إلى اللقاء")) {
//       return true;
//     }

//     return false;
//   }

//   // Wait for rate limiting - ensures we don't flood the API with requests
//   Future<void> _waitForRateLimit() async {
//     final now = DateTime.now();
//     final timeSinceLastRequest = now.difference(_lastRequestTime);

//     if (timeSinceLastRequest < _minRequestInterval) {
//       final waitTime = _minRequestInterval - timeSinceLastRequest;
//       print("⏱️ Rate limiting: waiting ${waitTime.inMilliseconds}ms before next API call");
//       await Future.delayed(waitTime);
//     }

//     _lastRequestTime = DateTime.now();
//   }

//   Future<void> initialize() async {
//     print("🔄 Initializing TTS service...");

//     // Only pre-cache the priority phrases - fewer chances of errors
//     final futures = <Future>[];

//     for (final phrase in _priorityPhrases) {
//       futures.add(_prefetchAudio(phrase).catchError((e) {
//         print("⚠️ Failed to cache priority phrase: $phrase");
//         return null;
//       }));
//     }

//     await Future.wait(futures);
//     print("✅ TTS service initialized with ${_audioCache.length} cached phrases");
//   }

//   Future<void> prefetchDynamic(List<String> phrases) async {
//     // Process in small batches with fewer total phrases
//     const batchSize = 2;
//     List<String> prunedList = phrases.take(4).toList(); // Only take a few phrases

//     for (int i = 0; i < prunedList.length; i += batchSize) {
//       final batch = prunedList.skip(i).take(batchSize);
//       final futures = <Future>[];

//       for (final phrase in batch) {
//         if (!_audioCache.containsKey(phrase)) {
//           futures.add(_prefetchAudio(phrase).catchError((e) {
//             print("⚠️ Failed to cache dynamic phrase: $phrase");
//             return null;
//           }));
//         }
//       }

//       await Future.wait(futures);

//       // Brief delay between batches
//       if (i + batchSize < phrases.length) {
//         await Future.delayed(Duration(milliseconds: 200));
//       }
//     }
//   }

//   Future<void> _prefetchAudio(String text) async {
//     if (_audioCache.containsKey(text)) return;

//     try {
//       // Wait for rate limiting
//       await _waitForRateLimit();

//       final url = Uri.parse("https://api.openai.com/v1/audio/speech");

//       final response = await http
//           .post(
//             url,
//             headers: {
//               "Authorization": "Bearer $_apiKey",
//               "Content-Type": "application/json",
//             },
//             body: jsonEncode({
//               "model": _model,
//               "input": text,
//               "voice": _voice,
//               "speed": 1.1,
//             }),
//           )
//           .timeout(Duration(seconds: 5));

//       if (response.statusCode == 200) {
//         _audioCache[text] = response.bodyBytes;
//         print("✅ Pre-cached: \"$text\"");
//       } else {
//         print("⚠️ Failed to cache \"$text\": ${response.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Error caching \"$text\": $e");
//       throw e;
//     }
//   }

//   // Play a single thinking phrase - no chaining
//   Future<void> playThinkingPhrase(String? childName) async {
//     // Don't play if: already playing, welcome message, or already played a thinking phrase
//     if (_isPlayingFillerPhrase || _isWelcomeOrEndingMessage || _thinkingPhraseAlreadyPlayed) {
//       return;
//     }

//     try {
//       // Select a simple thinking phrase
//       String phrase = "هممم دعني أفكر...";

//       // Check if phrase is in cache
//       if (_audioCache.containsKey(phrase)) {
//         print("▶️ Playing thinking phrase: \"$phrase\"");
//         _isPlayingFillerPhrase = true;
//         _thinkingPhraseAlreadyPlayed = true;

//         await _thinkingAudioPlayer.stop();
//         _thinkingAudioPlayer.play(BytesSource(_audioCache[phrase]!));
//       } else {
//         print("⚠️ No cached thinking phrases available");
//       }
//     } catch (e) {
//       print("❌ Error playing thinking phrase: $e");
//       _isPlayingFillerPhrase = false;
//     }
//   }

//   // Main speak method
//   Future<void> speak(String text, {String? childName, bool? isWelcomeOrEnding}) async {
//     if (text.trim().isEmpty) {
//       print("⚠️ Attempted to speak empty text, ignoring");
//       return;
//     }

//     try {
//       print("\n🔊 TTS speak() called for: '${text.substring(0, min(30, text.length))}...'");

//       // Always stop current playback and reset states
//       print("🛑 Stopping any current audio playback");
//       await stopAllAudio();

//       // Reset state for new TTS request
//       _isPlaying = true;
//       _thinkingPhraseAlreadyPlayed = false;
//       _errorMessageShown = false;

//       // Check if this is a welcome or ending message
//       _isWelcomeOrEndingMessage = isWelcomeOrEnding ?? _isWelcomeOrEnding(text);

//       if (_isWelcomeOrEndingMessage) {
//         print("🎭 This is a welcome or ending message - skipping thinking phrases");
//       }

//       // Check if this is already cached
//       if (_audioCache.containsKey(text)) {
//         // Found in cache, go straight to talking animation
//         print("▶️ Phrase found in cache: \"${text.substring(0, min(30, text.length))}...\"");

//         if (_audioReadyHandler != null) {
//           _audioReadyHandler!.call();
//         }

//         try {
//           print("▶️ Playing cached audio");
//           await _audioPlayer.play(BytesSource(_audioCache[text]!));
//           print("✅ Cached audio started playing");
//           return;
//         } catch (e) {
//           print("❌ Error playing cached audio: $e");
//           _handleError();
//           return;
//         }
//       }

//       // For non-cached phrases, show thinking animation
//       _isPreparingAudio = true;

//       if (_preparingAudioHandler != null) {
//         _preparingAudioHandler!.call();
//       }

//       print("🧠 Showing thinking animation while preparing audio");

//       // Play a single thinking phrase if not a welcome/ending message
//       if (!_isWelcomeOrEndingMessage) {
//         playThinkingPhrase(childName);
//       }

//       // Set a timeout for the TTS request
//       const ttsTimeout = Duration(seconds: 10);
//       final completer = Completer<Uint8List?>();

//       // Start the TTS request
//       requestTtsAudio(text).then((audio) {
//         if (!completer.isCompleted) completer.complete(audio);
//       }).catchError((e) {
//         if (!completer.isCompleted) completer.complete(null);
//         print("❌ TTS request error: $e");
//       });

//       // Set timeout
//       Future.delayed(ttsTimeout, () {
//         if (!completer.isCompleted) {
//           print("⚠️ TTS request timed out after ${ttsTimeout.inSeconds} seconds");
//           completer.complete(null);
//         }
//       });

//       // Wait for either completion or timeout
//       final audioBytes = await completer.future;

//       // Stop thinking phrases
//       await stopThinkingAudio();

//       if (audioBytes != null) {
//         print("✅ TTS audio received (${audioBytes.length} bytes)");

//         // Store in cache only if not too large
//         if (audioBytes.length < 200000) { // Reduced size for caching
//           _audioCache[text] = audioBytes;
//         }

//         // Signal ready for talking animation
//         _isPreparingAudio = false;
//         if (_audioReadyHandler != null) {
//           _audioReadyHandler!.call();
//         }

//         // Play the audio
//         await _audioPlayer.play(BytesSource(audioBytes));
//         print("▶️ Main TTS audio playback started");
//       } else {
//         print("❌ Failed to get TTS audio - using fallback");
//         _handleError();
//       }
//     } catch (e) {
//       print("❌ TTS outer error: $e");
//       _handleError();
//     }
//   }

//   // Handle errors in a consistent way
//   void _handleError() {
//     _isPlaying = false;
//     _isPreparingAudio = false;

//     // Only show error message once
//     if (!_errorMessageShown) {
//       _errorMessageShown = true;

//       // Try to play the error message if available in cache
//       final errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
//       if (_audioCache.containsKey(errorMsg)) {
//         if (_audioReadyHandler != null) {
//           _audioReadyHandler!.call();
//         }

//         _audioPlayer.play(BytesSource(_audioCache[errorMsg]!));
//       } else if (_completionHandler != null) {
//         _completionHandler!();
//       }
//     } else {
//       // If we already showed an error message, just call completion
//       if (_completionHandler != null) {
//         _completionHandler!();
//       }
//     }
//   }

//   // Make the TTS API request with simple retry
//   Future<Uint8List?> requestTtsAudio(String text) async {
//     int attempts = 0;
//     const maxAttempts = 2;

//     while (attempts < maxAttempts) {
//       try {
//         await _waitForRateLimit();

//         final url = Uri.parse("https://api.openai.com/v1/audio/speech");

//         print("🎤 Sending TTS API request (attempt ${attempts+1})");

//         final response = await http
//             .post(
//               url,
//               headers: {
//                 "Authorization": "Bearer $_apiKey",
//                 "Content-Type": "application/json",
//               },
//               body: jsonEncode({
//                 "model": _model,
//                 "input": text,
//                 "voice": _voice,
//               }),
//             )
//             .timeout(Duration(seconds: 7));

//         if (response.statusCode == 200) {
//           return response.bodyBytes;
//         } else {
//           print("❌ TTS API error: ${response.statusCode}");
//           attempts++;
//           if (attempts < maxAttempts) {
//             await Future.delayed(Duration(milliseconds: 500));
//           }
//         }
//       } catch (e) {
//         print("❌ TTS API request error: $e");
//         attempts++;
//         if (attempts < maxAttempts) {
//           await Future.delayed(Duration(milliseconds: 500));
//         }
//       }
//     }

//     return null;
//   }

//   // Stop main audio only
//   Future<void> stop() async {
//     print("🛑 TTS stop() called for main audio");

//     try {
//       _isPlaying = false;

//       // Stop main audio player
//       await _audioPlayer.stop().timeout(Duration(milliseconds: 300),
//         onTimeout: () {
//           print("⚠️ Main audio stop timeout - ignoring");
//           return;
//         });

//       if (_cancelHandler != null) {
//         _cancelHandler!();
//       }
//     } catch (e) {
//       print("⚠️ Error in stop(): $e");
//       _isPlaying = false;
//     }
//   }

//   // Stop thinking audio only
//   Future<void> stopThinkingAudio() async {
//     print("🛑 Stopping thinking phrases");

//     try {
//       // Cancel timer if active
//       _thinkingPhraseChainTimer?.cancel();
//       _thinkingPhraseChainTimer = null;

//       // Stop thinking audio player
//       await _thinkingAudioPlayer.stop().timeout(Duration(milliseconds: 300),
//         onTimeout: () {
//           print("⚠️ Thinking audio stop timeout - ignoring");
//           return;
//         });

//       _isPlayingFillerPhrase = false;
//     } catch (e) {
//       print("⚠️ Error stopping thinking audio: $e");
//       _isPlayingFillerPhrase = false;
//     }
//   }

//   // Stop all audio and reset states
//   Future<void> stopAllAudio() async {
//     print("🛑 Stopping all audio");

//     try {
//       // Cancel any active timers
//       _thinkingPhraseChainTimer?.cancel();
//       _thinkingPhraseChainTimer = null;

//       // Reset all state flags
//       _isPlaying = false;
//       _isPreparingAudio = false;
//       _isPlayingFillerPhrase = false;
//       // Don't reset welcome flag yet

//       // Stop both audio players in parallel
//       await Future.wait([
//         _audioPlayer.stop().timeout(Duration(milliseconds: 300),
//           onTimeout: () => print("⚠️ Main audio stop timeout")),
//         _thinkingAudioPlayer.stop().timeout(Duration(milliseconds: 300),
//           onTimeout: () => print("⚠️ Thinking audio stop timeout")),
//       ]);

//       if (_cancelHandler != null) {
//         _cancelHandler!();
//       }
//     } catch (e) {
//       print("⚠️ Error in stopAllAudio(): $e");
//       // Ensure states are reset even on error
//       _isPlaying = false;
//       _isPreparingAudio = false;
//       _isPlayingFillerPhrase = false;
//     }
//   }

//   // Public getters
//   bool get isPlaying => _isPlaying;
//   bool get isPreparingAudio => _isPreparingAudio;
// }

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGptTtsService {
  final String _apiKey;
  final String _voice;
  final String _model;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _thinkingAudioPlayer = AudioPlayer();
  final Map<String, Uint8List> _audioCache = {};

  // Rate limiting variables
  final Duration _minRequestInterval = Duration(milliseconds: 300);
  DateTime _lastRequestTime = DateTime.now().subtract(Duration(seconds: 10));

  // Retry configuration
  final int _maxRetries = 2; // Reduced to avoid excessive retries
  bool _isInWelcomeMode = false;

  Function? _completionHandler;
  Function? _cancelHandler;
  Function? _startPlaybackHandler;
  Function? _audioReadyHandler;
  Function? _preparingAudioHandler;

  bool _isPlaying = false;
  bool _isPreparingAudio = false;
  bool _isPlayingFillerPhrase = false;
  bool _isWelcomeOrEndingMessage = false;

  // Flag to prevent playing multiple thinking phrases
  bool _thinkingPhraseAlreadyPlayed = false;

  // Flag to prevent duplicate error messages
  bool _errorMessageShown = false;

  // Flag to track if we're in game mode
  bool _isInGameMode = false;
  bool _isPlayingWaitingPhrase = false;

  Timer? _thinkingPhraseChainTimer;
  final List<String> _waitingPhrases = [
    "أنا أفكر...",
    "لحظة من فضلك...",
    "دعني أفكر في ذلك...",
    "حسناً، دعني أرى..."
  ];
  // Only ending phrases as requested
  final List<String> _endingPhrases = [
    "الى اللقاء",
    "إلى اللقاء",
    "وداعاً",
    "مع السلامة",
  ];

  // Game-specific phrases to cache
  final List<String> _gamePhrases = [
    "برافو! أحسنت",
    "حاول تاني",
    "برافو! الإجابة صحيحة"
  ];

  void setWelcomeMessageMode(bool inWelcomeMode) {
    _isInWelcomeMode = inWelcomeMode;
    print("🔊 Welcome message mode set to: $_isInWelcomeMode");

    // Welcome mode should suppress waiting phrases like game mode does
    if (_isInWelcomeMode) {
      // Store current game mode state to restore it later
      _wasInGameMode = _isInGameMode;
      // Force game mode while in welcome mode to suppress waiting phrases
      _isInGameMode = true;
    } else if (!_wasInGameMode) {
      // Only reset game mode if it wasn't set before
      _isInGameMode = false;
    }
  }

// Store previous game mode state
  bool _wasInGameMode = false;

  bool get isInWelcomeMode => _isInWelcomeMode;

  ChatGptTtsService(
      {String? apiKey, String voice = 'nova', String model = 'gpt-4o-mini-tts'})
      : _apiKey = apiKey ?? dotenv.env['OPEN_AI_API_KEY'] ?? '',
        _voice = voice,
        _model = model {
    // Main audio player completion listener
    _audioPlayer.onPlayerComplete.listen((_) {
      print("✅ Main audio playback completed");
      _isPlaying = false;
      _isWelcomeOrEndingMessage = false;
      _errorMessageShown = false;

      if (_completionHandler != null) {
        _completionHandler!();
      }
    });

    // Main audio player state change listener
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        if (_startPlaybackHandler != null) {
          _startPlaybackHandler!();
        }
      } else if (state == PlayerState.completed) {
        _isPlaying = false;
        _isWelcomeOrEndingMessage = false;
        _errorMessageShown = false;

        if (_completionHandler != null) {
          _completionHandler!();
        }
      }
    });

    // Thinking audio player state change listener
    _thinkingAudioPlayer.onPlayerComplete.listen((_) {
      print("✅ Thinking phrase completed");
      _isPlayingFillerPhrase = false;

      // Don't chain multiple thinking phrases - this is what's causing multiple plays
      // Instead, mark that we've already played one
      _thinkingPhraseAlreadyPlayed = true;
    });
  }

  void setGameMode(bool inGameMode) {
    // Add debug logs to track state changes
    print("🎮 Game mode changing from: $_isInGameMode to: $inGameMode");
    _isInGameMode = inGameMode;
    print("🎮 Game mode now set to: $_isInGameMode");

    // Stop any playing waiting phrases immediately if entering game mode
    if (_isInGameMode && _isPlayingWaitingPhrase) {
      print("🎮 Game mode activated - stopping any playing waiting phrases");
      try {
        _thinkingAudioPlayer.stop();
        _isPlayingWaitingPhrase = false;
      } catch (e) {
        print("⚠️ Error stopping thinking audio: $e");
      }
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

  void setAudioReadyHandler(Function callback) {
    _audioReadyHandler = callback;
  }

  void setPreparingAudioHandler(Function callback) {
    _preparingAudioHandler = callback;
  }

  // Check if a phrase is a ending message
  bool _isEndingMessage(String text) {
    String lowerText = text.toLowerCase();

    // Check if the text starts with any ending phrase
    for (final phrase in _endingPhrases) {
      if (lowerText.startsWith(phrase.toLowerCase())) {
        return true;
      }
    }

    // Additional checks for ending patterns
    if (lowerText.contains("الى اللقاء") || lowerText.contains("إلى اللقاء")) {
      return true;
    }

    return false;
  }

  // Wait for rate limiting - ensures we don't flood the API with requests
  Future<void> _waitForRateLimit() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);

    if (timeSinceLastRequest < _minRequestInterval) {
      final waitTime = _minRequestInterval - timeSinceLastRequest;
      print(
          "⏱️ Rate limiting: waiting ${waitTime.inMilliseconds}ms before next API call");
      await Future.delayed(waitTime);
    }

    _lastRequestTime = DateTime.now();
  }

  Future<void> initialize() async {
    print("🔄 Initializing TTS service...");

    // Pre-cache priority phrases and waiting phrases
    final allPhrasesToCache = [..._gamePhrases, ..._waitingPhrases];

    final futures = <Future>[];

    for (final phrase in allPhrasesToCache) {
      futures.add(_prefetchAudio(phrase).catchError((e) {
        print("⚠️ Failed to cache phrase: $phrase");
        return null;
      }));
    }

    await Future.wait(futures);
    print(
        "✅ TTS service initialized with ${_audioCache.length} cached phrases");
  }

// Find this method in your ChatGptTtsService class and replace it with this version
  void _playRandomWaitingPhrase() {
    // Add a more explicit debug message to confirm why waiting phrases are skipped
    if (_isPlayingWaitingPhrase ||
        _isInGameMode ||
        _isWelcomeOrEndingMessage ||
        _isInWelcomeMode) {
      if (_isInGameMode) {
        print(
            "🎮 Skipping waiting phrase - game mode active (_isInGameMode=true)");
      } else if (_isInWelcomeMode) {
        print(
            "👋 Skipping waiting phrase - welcome mode active (_isInWelcomeMode=true)");
      } else if (_isWelcomeOrEndingMessage) {
        print("🎭 Skipping waiting phrase - welcome/ending message active");
      } else {
        print(
            "⏳ Skipping waiting phrase - already playing another waiting phrase");
      }
      return;
    }

    // Pick a random waiting phrase
    final phrases = _waitingPhrases
        .where((phrase) => _audioCache.containsKey(phrase))
        .toList();

    if (phrases.isEmpty) {
      print("⚠️ No cached waiting phrases available");
      return;
    }

    try {
      final phrase = phrases[Random().nextInt(phrases.length)];
      print("▶️ Playing waiting phrase: \"$phrase\"");
      _isPlayingWaitingPhrase = true;

      // Play the waiting phrase
      _thinkingAudioPlayer.stop().then((_) {
        _thinkingAudioPlayer.play(BytesSource(_audioCache[phrase]!));
      });

      // After a short delay, mark as complete
      Future.delayed(Duration(seconds: 2), () {
        _isPlayingWaitingPhrase = false;
      });
    } catch (e) {
      print("❌ Error playing waiting phrase: $e");
      _isPlayingWaitingPhrase = false;
    }
  }

  Future<void> prefetchDynamic(List<String> phrases) async {
    // Process in small batches with fewer total phrases
    const batchSize = 2;
    List<String> prunedList =
        phrases.take(4).toList(); // Only take a few phrases

    for (int i = 0; i < prunedList.length; i += batchSize) {
      final batch = prunedList.skip(i).take(batchSize);
      final futures = <Future>[];

      for (final phrase in batch) {
        if (!_audioCache.containsKey(phrase)) {
          futures.add(_prefetchAudio(phrase).catchError((e) {
            print("⚠️ Failed to cache dynamic phrase: $phrase");
            return null;
          }));
        }
      }

      await Future.wait(futures);

      // Brief delay between batches
      if (i + batchSize < phrases.length) {
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
  }

  Future<void> _prefetchAudio(String text) async {
    if (_audioCache.containsKey(text)) return;

    try {
      // Wait for rate limiting
      await _waitForRateLimit();

      final url = Uri.parse("https://api.openai.com/v1/audio/speech");

      final response = await http
          .post(
            url,
            headers: {
              "Authorization": "Bearer $_apiKey",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model": _model,
              "input": text,
              "voice": _voice,
              "speed": 1.1,
            }),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        _audioCache[text] = response.bodyBytes;
        print("✅ Pre-cached: \"$text\"");
      } else {
        print("⚠️ Failed to cache \"$text\": ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error caching \"$text\": $e");
      throw e;
    }
  }

  // Play a single thinking phrase - no chaining
  // Check game mode flag to skip thinking phrases during games
  Future<void> playThinkingPhrase(String? childName) async {
    // Check if we should skip playing thinking phrase
    if (_isPlayingFillerPhrase ||
        _isWelcomeOrEndingMessage ||
        _thinkingPhraseAlreadyPlayed ||
        _isInGameMode) {
      // Added game mode check here

      if (_isInGameMode) {
        print("🎮 Skipping thinking phrase - game mode active");
      }
      return;
    }

    try {
      // Select a simple thinking phrase
      String phrase = "هممم دعني أفكر...";

      // Check if phrase is in cache
      if (_audioCache.containsKey(phrase)) {
        print("▶️ Playing thinking phrase: \"$phrase\"");
        _isPlayingFillerPhrase = true;
        _thinkingPhraseAlreadyPlayed = true;

        await _thinkingAudioPlayer.stop();
        _thinkingAudioPlayer.play(BytesSource(_audioCache[phrase]!));
      } else {
        print("⚠️ No cached thinking phrases available");
      }
    } catch (e) {
      print("❌ Error playing thinking phrase: $e");
      _isPlayingFillerPhrase = false;
    }
  }

  // Modified speak method to use waiting phrases
  Future<void> speak(String text,
      {String? childName, bool? isWelcomeOrEnding}) async {
    if (text.trim().isEmpty) {
      print("⚠️ Attempted to speak empty text, ignoring");
      return;
    }

    try {
      print(
          "\n🔊 TTS speak() called for: '${text.substring(0, min(30, text.length))}...'");

      // Always stop current playback and reset states
      print("🛑 Stopping any current audio playback");
      await stopAllAudio();

      // Reset state for new TTS request
      _isPlaying = true;
      _thinkingPhraseAlreadyPlayed = false;
      _errorMessageShown = false;

      // Check if this is a welcome message
      _isWelcomeOrEndingMessage = isWelcomeOrEnding ?? _isEndingMessage(text);

      if (_isWelcomeOrEndingMessage || _isInWelcomeMode || _isInGameMode) {
        print(
            "🎭 This is a welcome/ending message or in game/welcome mode - skipping waiting phrases");
      }

      // Check if this is already cached
      if (_audioCache.containsKey(text)) {
        // Found in cache, go straight to talking animation
        print(
            "▶️ Phrase found in cache: \"${text.substring(0, min(30, text.length))}...\"");

        if (_audioReadyHandler != null) {
          _audioReadyHandler!.call();
        }

        try {
          print("▶️ Playing cached audio");
          await _audioPlayer.play(BytesSource(_audioCache[text]!));
          print("✅ Cached audio started playing");
          return;
        } catch (e) {
          print("❌ Error playing cached audio: $e");
          _handleError();
          return;
        }
      }

      // For non-cached phrases, show thinking animation
      _isPreparingAudio = true;

      if (_preparingAudioHandler != null) {
        _preparingAudioHandler!.call();
      }

      print("🧠 Showing thinking animation while preparing audio");

      // Play a random waiting phrase if not a welcome/ending message and not in game/welcome mode
      if (!_isWelcomeOrEndingMessage && !_isInGameMode && !_isInWelcomeMode) {
        _playRandomWaitingPhrase();
      }

      // Set a timeout for the TTS request
      const ttsTimeout = Duration(seconds: 10);
      final completer = Completer<Uint8List?>();

      // Start the TTS request
      requestTtsAudio(text).then((audio) {
        if (!completer.isCompleted) completer.complete(audio);
      }).catchError((e) {
        if (!completer.isCompleted) completer.complete(null);
        print("❌ TTS request error: $e");
      });

      // Set timeout
      Future.delayed(ttsTimeout, () {
        if (!completer.isCompleted) {
          print(
              "⚠️ TTS request timed out after ${ttsTimeout.inSeconds} seconds");
          completer.complete(null);
        }
      });

      // Wait for either completion or timeout
      final audioBytes = await completer.future;

      // Stop thinking phrases
      await stopThinkingAudio();

      if (audioBytes != null) {
        print("✅ TTS audio received (${audioBytes.length} bytes)");

        // Store in cache only if not too large
        if (audioBytes.length < 200000) {
          // Reduced size for caching
          _audioCache[text] = audioBytes;
        }

        // Signal ready for talking animation
        _isPreparingAudio = false;
        if (_audioReadyHandler != null) {
          _audioReadyHandler!.call();
        }

        // Play the audio
        await _audioPlayer.play(BytesSource(audioBytes));
        print("▶️ Main TTS audio playback started");
      } else {
        print("❌ Failed to get TTS audio - using fallback");
        _handleError();
      }
    } catch (e) {
      print("❌ TTS outer error: $e");
      _handleError();
    }
  }

  // Add missing getters

  // Handle errors in a consistent way
  void _handleError() {
    _isPlaying = false;
    _isPreparingAudio = false;

    // Only show error message once
    if (!_errorMessageShown) {
      _errorMessageShown = true;

      // Try to play the error message if available in cache
      final errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      if (_audioCache.containsKey(errorMsg)) {
        if (_audioReadyHandler != null) {
          _audioReadyHandler!.call();
        }

        _audioPlayer.play(BytesSource(_audioCache[errorMsg]!));
      } else if (_completionHandler != null) {
        _completionHandler!();
      }
    } else {
      // If we already showed an error message, just call completion
      if (_completionHandler != null) {
        _completionHandler!();
      }
    }
  }

  // Make the TTS API request with simple retry
  Future<Uint8List?> requestTtsAudio(String text) async {
    int attempts = 0;
    const maxAttempts = 2;

    while (attempts < maxAttempts) {
      try {
        await _waitForRateLimit();

        final url = Uri.parse("https://api.openai.com/v1/audio/speech");

        print("🎤 Sending TTS API request (attempt ${attempts + 1})");

        final response = await http
            .post(
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
            )
            .timeout(Duration(seconds: 7));

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          print("❌ TTS API error: ${response.statusCode}");
          attempts++;
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      } catch (e) {
        print("❌ TTS API request error: $e");
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    return null;
  }

  // Stop main audio only
  Future<void> stop() async {
    print("🛑 TTS stop() called for main audio");

    try {
      _isPlaying = false;

      // Stop main audio player
      await _audioPlayer.stop().timeout(Duration(milliseconds: 300),
          onTimeout: () {
        print("⚠️ Main audio stop timeout - ignoring");
        return;
      });

      if (_cancelHandler != null) {
        _cancelHandler!();
      }
    } catch (e) {
      print("⚠️ Error in stop(): $e");
      _isPlaying = false;
    }
  }

  // Stop thinking audio only
  Future<void> stopThinkingAudio() async {
    print("🛑 Stopping thinking phrases");

    try {
      // Cancel timer if active
      _thinkingPhraseChainTimer?.cancel();
      _thinkingPhraseChainTimer = null;

      // Stop thinking audio player
      await _thinkingAudioPlayer.stop().timeout(Duration(milliseconds: 300),
          onTimeout: () {
        print("⚠️ Thinking audio stop timeout - ignoring");
        return;
      });

      _isPlayingFillerPhrase = false;
    } catch (e) {
      print("⚠️ Error stopping thinking audio: $e");
      _isPlayingFillerPhrase = false;
    }
  }

  // Stop all audio and reset states
  Future<void> stopAllAudio() async {
    print("🛑 Stopping all audio");

    try {
      // Cancel any active timers
      _thinkingPhraseChainTimer?.cancel();
      _thinkingPhraseChainTimer = null;

      // Reset all state flags
      _isPlaying = false;
      _isPreparingAudio = false;
      _isPlayingFillerPhrase = false;
      // Don't reset welcome flag yet

      // Stop both audio players in parallel
      await Future.wait([
        _audioPlayer.stop().timeout(Duration(milliseconds: 300),
            onTimeout: () => print("⚠️ Main audio stop timeout")),
        _thinkingAudioPlayer.stop().timeout(Duration(milliseconds: 300),
            onTimeout: () => print("⚠️ Thinking audio stop timeout")),
      ]);

      if (_cancelHandler != null) {
        _cancelHandler!();
      }
    } catch (e) {
      print("⚠️ Error in stopAllAudio(): $e");
      // Ensure states are reset even on error
      _isPlaying = false;
      _isPreparingAudio = false;
      _isPlayingFillerPhrase = false;
    }
  }

  // Public getters
  bool get isPlaying => _isPlaying;
  bool get isPreparingAudio => _isPreparingAudio;
  bool get isInGameMode => _isInGameMode;
  bool get isPlayingWaitingPhrase => _isPlayingWaitingPhrase;
}
