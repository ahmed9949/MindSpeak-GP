import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TTSService {
  static final _apiKey = dotenv.env['EL_API_KEY'] ?? '';

  Future<List<int>> synthesizeSpeech(String text) async {
    if (_apiKey.isEmpty) {
      throw Exception('ElevenLabs API key not found in .env file.');
    }

    // Possibly check if text is too long, and trim or chunk it
    final shortenedText = (text.length > 600) 
      ? text.substring(0, 600) 
      : text;

    const voiceId = '21m00Tcm4TlvDq8ikWAM';
    final url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';

    final startTime = DateTime.now();
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'accept': 'audio/mpeg',
            'xi-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: json.encode({
            "text": shortenedText,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": {
              "stability": 0.1,        // lower stability
              "similarity_boost": 0.5, // reduce similarity
            }
          }),
        )
        .timeout(const Duration(seconds: 15));

    final endTime = DateTime.now();
    print("TTS request took ${endTime.difference(startTime).inMilliseconds} ms");

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      final errorResponse = json.decode(response.body);
      throw HttpException(
        'ElevenLabs API error: ${response.statusCode} - '
        '${errorResponse['detail'] ?? response.body}',
      );
    }
  }
}