// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class TTSService {
//   static final _apiKey = dotenv.env['EL_API_KEY'] ?? '';

//   Future<List<int>> synthesizeSpeech(String text) async {
//     if (_apiKey.isEmpty) {
//       throw Exception('ElevenLabs API key not found in .env file.');
//     }

//     // Possibly check if text is too long, and trim or chunk it
//     final shortenedText = (text.length > 600) 
//       ? text.substring(0, 600) 
//       : text;

//     const voiceId = '21m00Tcm4TlvDq8ikWAM';
//     const url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';

//     final startTime = DateTime.now();
//     final response = await http
//         .post(
//           Uri.parse(url),
//           headers: {
//             'accept': 'audio/mpeg',
//             'xi-api-key': _apiKey,
//             'Content-Type': 'application/json',
//           },
//           body: json.encode({
//             "text": shortenedText,
//             "model_id": "eleven_monolingual_v1",
//             "voice_settings": {
//               "stability": 0.1,        // lower stability
//               "similarity_boost": 0.5, // reduce similarity
//             }
//           }),
//         )
//         .timeout(const Duration(seconds: 15));

//     final endTime = DateTime.now();
//     print("TTS request took ${endTime.difference(startTime).inMilliseconds} ms");

//     if (response.statusCode == 200) {
//       return response.bodyBytes;
//     } else {
//       final errorResponse = json.decode(response.body);
//       throw HttpException(
//         'ElevenLabs API error: ${response.statusCode} - '
//         '${errorResponse['detail'] ?? response.body}',
//       );
//     }
//   }
// }



import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped }

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  TtsState _ttsState = TtsState.stopped;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure TTS settings
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    // Set up error handler
    _flutterTts.setErrorHandler((message) {
      _ttsState = TtsState.stopped;
      print('TTS Error: $message');
    });

    // Set up start handler
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_ttsState == TtsState.playing) {
      await stop();
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _ttsState = TtsState.stopped;
  }

  Future<void> dispose() async {
    await stop();
  }

  bool isSpeaking() {
    return _ttsState == TtsState.playing;
  }

  // Optional: Get available voices and languages
  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return languages.cast<String>();
  }
}