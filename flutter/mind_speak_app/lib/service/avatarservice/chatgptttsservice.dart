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

  bool _isPlaying = false;

  final List<String> _commonPhrases = [
    "برافو! أحسنت",
    "حاول تاني",
    "برافو! الإجابة صحيحة",
    "لا، حاول مرة أخرى"
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

  void setCancelHandler(Function callback) {
    _cancelHandler = callback;
  }

  void setStartPlaybackHandler(Function callback) {
    _startPlaybackHandler = callback;
  }

  Future<void> initialize() async {
    print("🔄 Initializing TTS service...");
    for (final phrase in _commonPhrases) {
      await _prefetchAudio(phrase);
    }
    print("✅ Common TTS phrases preloaded");
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

  Future<void> speak(String text) async {
    try {
      await stop(); // stop current speech
      _isPlaying = true;

      if (_audioCache.containsKey(text)) {
        print("▶️ Playing from cache: \"$text\"");
        await _audioPlayer.play(BytesSource(_audioCache[text]!));
        return;
      }

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

      if (response.statusCode == 200) {
        if (!_isPlaying) return;
        Uint8List audioBytes = response.bodyBytes;
        _audioCache[text] = audioBytes;
        await _audioPlayer.play(BytesSource(audioBytes));
        print("▶️ TTS playback started");
      } else {
        _isPlaying = false;
        throw Exception('TTS error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _isPlaying = false;
      print("❌ TTS speak error: $e");
    }
  }

  Future<void> stop() async {
    if (_isPlaying) {
      _isPlaying = false;
      await _audioPlayer.stop();
      _cancelHandler?.call();
    }
  }

  bool get isPlaying => _isPlaying;
}
