// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ChatGptTtsService {
//   final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
//   final String _voice = 'nova';
//   final String _model = 'gpt-4o-mini-tts'; // or 'tts-1-hd'

//   final AudioPlayer _audioPlayer = AudioPlayer();

//  Future<void> speak(String text) async {
//   try {
//     final url = Uri.parse("https://api.openai.com/v1/audio/speech");
    
//     print("Sending TTS request for text: \"${text.substring(0, min(30, text.length))}...\"");
    
//     final response = await http.post(
//       url,
//       headers: {
//         "Authorization": "Bearer $_apiKey",
//         "Content-Type": "application/json",
//       },
//       body: jsonEncode({
//         "model": _model,
//         "input": text,
//         "voice": _voice,
//       }),
//     );

//     if (response.statusCode == 200) {
//       print("TTS API returned audio data successfully");
//       Uint8List audioBytes = response.bodyBytes;
//       await _audioPlayer.play(BytesSource(audioBytes));
//       print("Audio playback started");
//     } else {
//       print('TTS API error: ${response.statusCode} - ${response.body}');
//       throw Exception('Failed to generate speech: ${response.statusCode}');
//     }
//   } catch (e) {
//     print('Error in speak method: $e');
//     throw Exception('TTS service error: $e');
//   }
// }

//  Future<void> stop() async {
//     await _audioPlayer.stop();
//   }
// }




// Updated ChatGptTtsService.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ChatGptTtsService {
  final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
  final String _voice = 'nova';
  final String _model = 'gpt-4o-mini-tts'; // or 'tts-1-hd'

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Add a cache for audio responses
  final Map<String, Uint8List> _audioCache = {};

  bool _isPlaying = false;

  // Common phrases used in the game
  final List<String> _commonPhrases = [
    "برافو! أحسنت",
    "حاول تاني",
    "برافو! الإجابة صحيحة",
    "لا، حاول مرة أخرى"
  ];

  ChatGptTtsService() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
    });
  }

  // Method to initialize and preload audio
  Future<void> initialize() async {
    print("Initializing TTS service and preloading common phrases...");
    for (final phrase in _commonPhrases) {
      await _prefetchAudio(phrase);
    }
    print("TTS initialization complete");
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
          "speed": 1.1, // Slightly faster playback
        }),
      );

      if (response.statusCode == 200) {
        _audioCache[text] = response.bodyBytes;
        print("✅ Pre-cached audio for: $text");
      }
    } catch (e) {
      print('❌ Error pre-fetching audio: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      // Wait for any existing audio to finish
      if (_isPlaying) {
        await _audioPlayer.stop();
        // Small delay to ensure clean transition
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isPlaying = true;

      // Check if we already have this audio cached
      if (_audioCache.containsKey(text)) {
        print("Using cached audio for: $text");
        await _audioPlayer.play(BytesSource(_audioCache[text]!));
        return;
      }

      final url = Uri.parse("https://api.openai.com/v1/audio/speech");

      print(
          "Sending TTS request for text: \"${text.substring(0, min(30, text.length))}...\"");

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
          print("TTS API returned audio data successfully");
        
        // Check if we've been interrupted during the API call
        if (!_isPlaying) {
          print("Speech was cancelled before audio started playing");
          return;
        }
        
          Uint8List audioBytes = response.bodyBytes;
  
        // Cache this audio for future use
        _audioCache[text] = audioBytes;

        await _audioPlayer.play(BytesSource(audioBytes));
          print("Audio playback started");
        } else {
        _isPlaying = false;
          _isPlaying = false;
        print('TTS API error: ${response.statusCode} - ${response.body}');
          throw Exception('Failed to generate speech: ${response.statusCode}');
        }
      } catch (e) {
      _isPlaying = false;
        _isPlaying = false;
      print('Error in speak method: $e');
        throw Exception('TTS service error: $e');
      }
    }

   Future<void> stop() async {
    if (_isPlaying) {
      _isPlaying = false;
      await _audioPlayer.stop();
      // Call the cancel handler when stopping manually
      if (_cancelHandler != null) {
        _cancelHandler!();
      }
      _isPlaying = false;
  }
  }
  
  bool get isPlaying => _isPlaying;
}