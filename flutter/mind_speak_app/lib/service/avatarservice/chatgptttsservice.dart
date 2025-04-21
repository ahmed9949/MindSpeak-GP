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
  Function? _completionHandler;
  Function? _cancelHandler;
  Function? _startPlaybackHandler; // New handler for when audio actually starts
  bool _isPlaying = false;

  ChatGptTtsService() {
    // Add listener for audio completion
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      if (_completionHandler != null) {
        _completionHandler!();
      }
    });
    
    // Monitor player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        // Audio is actually playing now
        if (_startPlaybackHandler != null) {
          _startPlaybackHandler!();
        }
      } else if (state == PlayerState.completed) {
        _isPlaying = false;
        if (_completionHandler != null) {
          _completionHandler!();
        }
      }
    });
  }

  void setCompletionHandler(Function callback) {
    _completionHandler = callback;
  }

  void setCancelHandler(Function callback) {
    _cancelHandler = callback;
  }
  
  // New method to set handler for actual playback start
  void setStartPlaybackHandler(Function callback) {
    _startPlaybackHandler = callback;
  }
 
  Future<void> speak(String text) async {
    try {
      // Stop any current playback
      await stop();
      
      final url = Uri.parse("https://api.openai.com/v1/audio/speech");
      
      print("Sending TTS request for text: \"${text.substring(0, min(30, text.length))}...\"");
      
      // Notify that we're preparing speech (but not playing yet)
      _isPlaying = true;
      
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
        await _audioPlayer.play(BytesSource(audioBytes));
        print("Audio playback started");
      } else {
        _isPlaying = false;
        print('TTS API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate speech: ${response.statusCode}');
      }
    } catch (e) {
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
    }
  }
  
  bool get isPlaying => _isPlaying;
}