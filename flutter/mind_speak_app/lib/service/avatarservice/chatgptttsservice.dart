// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// // Enhanced ChatGptTtsService with better synchronization
// class ChatGptTtsService {
//   final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
//   final String _voice = 'nova';
//   final String _model = 'gpt-4o-mini-tts';

//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final Map<String, Uint8List> _audioCache = {}; // ✅ cache

//   Function? _completionHandler;
//   Function? _cancelHandler;
//   Function? _startPlaybackHandler;
//   Function? _audioReadyHandler; // New callback for when audio is ready

//   bool _isPlaying = false;
//   bool _isPreparingAudio = false; // Track when we're fetching audio

//   final List<String> _commonPhrases = [
//     "برافو! أحسنت",
//     "حاول تاني",
//     "برافو! الإجابة صحيحة",
//     "لا، حاول مرة أخرى"
//   ];

//   ChatGptTtsService() {
//     _audioPlayer.onPlayerComplete.listen((_) {
//       _isPlaying = false;
//       _completionHandler?.call();
//     });

//     _audioPlayer.onPlayerStateChanged.listen((state) {
//       if (state == PlayerState.playing) {
//         _startPlaybackHandler?.call();
//       } else if (state == PlayerState.completed) {
//         _isPlaying = false;
//         _completionHandler?.call();
//       }
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

//   // New: Set a callback for when audio is ready but before playback
//   void setAudioReadyHandler(Function callback) {
//     _audioReadyHandler = callback;
//   }

//   Future<void> initialize() async {
//     print("🔄 Initializing TTS service...");
//     for (final phrase in _commonPhrases) {
//       await _prefetchAudio(phrase);
//     }
//     print("✅ Common TTS phrases preloaded");
//   }

//   Future<void> prefetchDynamic(List<String> phrases) async {
//     for (final phrase in phrases) {
//       if (!_audioCache.containsKey(phrase)) {
//         await _prefetchAudio(phrase);
//       }
//     }
//   }

//   Future<void> _prefetchAudio(String text) async {
//     if (_audioCache.containsKey(text)) return;

//     try {
//       final url = Uri.parse("https://api.openai.com/v1/audio/speech");

//       final response = await http.post(
//         url,
//         headers: {
//           "Authorization": "Bearer $_apiKey",
//           "Content-Type": "application/json",
//         },
//         body: jsonEncode({
//           "model": _model,
//           "input": text,
//           "voice": _voice,
//           "speed": 1.1, // Slight speed boost
//         }),
//       );

//       if (response.statusCode == 200) {
//         _audioCache[text] = response.bodyBytes;
//         print("✅ Pre-cached: \"$text\"");
//       } else {
//         print("❌ Failed to cache \"$text\": ${response.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Error caching \"$text\": $e");
//     }
//   }

//   Future<void> speak(String text) async {
//     try {
//       await stop(); // stop current speech
//       _isPlaying = true;

//       Uint8List audioBytes;

//       if (_audioCache.containsKey(text)) {
//         print("▶️ Using cached audio for: \"$text\"");
//         audioBytes = _audioCache[text]!;

//         // Signal that audio is ready before playing
//         _audioReadyHandler?.call();

//         // Small delay to allow animation to start
//         await Future.delayed(const Duration(milliseconds: 50));

//         await _audioPlayer.play(BytesSource(audioBytes));
//         return;
//       }

//       final url = Uri.parse("https://api.openai.com/v1/audio/speech");

//       print(
//           "🎤 Requesting TTS for: \"${text.substring(0, min(30, text.length))}...\"");

//       final response = await http.post(
//         url,
//         headers: {
//           "Authorization": "Bearer $_apiKey",
//           "Content-Type": "application/json",
//         },
//         body: jsonEncode({
//           "model": _model,
//           "input": text,
//           "voice": _voice,
//         }),
//       );

//       if (response.statusCode == 200) {
//         if (!_isPlaying) return;
//         audioBytes = response.bodyBytes;
//         _audioCache[text] = audioBytes;

//         // Signal that audio is ready before playing
//         _audioReadyHandler?.call();

//         // Small delay to allow animation to start
//         await Future.delayed(const Duration(milliseconds: 50));

//         await _audioPlayer.play(BytesSource(audioBytes));
//         print("▶️ TTS playback started");
//       } else {
//         _isPlaying = false;
//         throw Exception('TTS error: ${response.statusCode} - ${response.body}');
//       }
//     } catch (e) {
//       _isPlaying = false;
//       print("❌ TTS speak error: $e");
//     }
//   }

//   Future<void> stop() async {
//     if (_isPlaying) {
//       _isPlaying = false;
//       await _audioPlayer.stop();
//       _cancelHandler?.call();
//     }
//   }

//   bool get isPlaying => _isPlaying;
// }

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
  final Map<String, Uint8List> _audioCache = {};

  Function? _completionHandler;
  Function? _cancelHandler;
  Function? _startPlaybackHandler;
  Function? _audioReadyHandler;
  Function? _preparingAudioHandler; // New: Called when waiting for audio

  bool _isPlaying = false;
  bool _isPreparingAudio = false;

  // Expanded list of common phrases that will be pre-cached
  final List<String> _commonPhrases = [
    "برافو! أحسنت",
    "حاول تاني",
    "جميل جدا",
    "ممتاز",
    "أحسنت",
    "رائع",
    "نعم",
    "لا",
    "مرة أخرى",
    "حاول مرة أخرى",
    "برافو! الإجابة صحيحة",
    "لا، حاول مرة أخرى",
    "فكر جيدا",
    "هذا صحيح"
  ];

  ChatGptTtsService(
      {String? apiKey, String voice = 'nova', String model = 'gpt-4o-mini-tts'})
      : _apiKey = apiKey ?? dotenv.env['OPEN_AI_API_KEY'] ?? '',
        _voice = voice,
        _model = model {
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

  void setCancelHandler(Function callback) {
    _cancelHandler = callback;
  }

  void setStartPlaybackHandler(Function callback) {
    _startPlaybackHandler = callback;
  }

  void setAudioReadyHandler(Function callback) {
    _audioReadyHandler = callback;
  }

  // New: Set a callback for when we're waiting for audio
  void setPreparingAudioHandler(Function callback) {
    _preparingAudioHandler = callback;
  }

  Future<void> initialize() async {
    print("🔄 Initializing TTS service...");

    // Pre-cache all the common phrases in parallel for efficiency
    final futures = <Future>[];
    for (final phrase in _commonPhrases) {
      futures.add(_prefetchAudio(phrase));
    }

    await Future.wait(futures);
    print("✅ ${_commonPhrases.length} common TTS phrases preloaded");
  }

  Future<void> prefetchDynamic(List<String> phrases) async {
    final futures = <Future>[];
    for (final phrase in phrases) {
      if (!_audioCache.containsKey(phrase)) {
        futures.add(_prefetchAudio(phrase));
      }
    }
    await Future.wait(futures);
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

  Future<void> speak(String text) async {
    try {
      await stop(); // stop current speech
      _isPlaying = true;

      // Check if this is a short common phrase that might be cached
      final isCommonPhrase = _commonPhrases.contains(text) ||
          _audioCache.containsKey(text) ||
          text.length < 15;

      if (isCommonPhrase && _audioCache.containsKey(text)) {
        // For common phrases that are cached, go straight to talking animation
        print("▶️ Common phrase found in cache: \"$text\"");
        _audioReadyHandler?.call(); // Start talking animation immediately

        // Small delay to ensure animation has time to start
        await Future.delayed(const Duration(milliseconds: 50));

        await _audioPlayer.play(BytesSource(_audioCache[text]!));
        return;
      }

      // For longer non-cached phrases, show thinking animation while waiting
      _isPreparingAudio = true;
      _preparingAudioHandler?.call(); // Start thinking animation
      print("🧠 Showing thinking animation while preparing audio");

      final url = Uri.parse("https://api.openai.com/v1/audio/speech");

      print(
          "🎤 Requesting TTS for: \"${text.substring(0, min(30, text.length))}...\"");

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

      if (response.statusCode == 200) {
        if (!_isPlaying) return;

        _isPreparingAudio = false;
        Uint8List audioBytes = response.bodyBytes;
        _audioCache[text] = audioBytes;

        // Now that audio is ready, switch to talking animation
        _audioReadyHandler?.call();

        // Small delay to ensure animation has time to switch
        await Future.delayed(const Duration(milliseconds: 50));

        await _audioPlayer.play(BytesSource(audioBytes));
        print("▶️ TTS audio playback started");
      } else {
        _isPlaying = false;
        _isPreparingAudio = false;
        throw Exception('TTS error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _isPlaying = false;
      _isPreparingAudio = false;
      print("❌ TTS speak error: $e");
    }
  }

  Future<void> stop() async {
    if (_isPlaying) {
      _isPlaying = false;
      _isPreparingAudio = false;
      await _audioPlayer.stop();
      _cancelHandler?.call();
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isPreparingAudio => _isPreparingAudio;
}
