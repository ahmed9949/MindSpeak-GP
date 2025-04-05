import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGptTtsService {
  final String _apiKey = dotenv.env['OPEN_AI_API_KEY']!;
  final String _voice = 'nova';
  final String _model = 'gpt-4o-mini-tts'; // or 'tts-1-hd'

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> speak(String text) async {
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
      }),
    );

    if (response.statusCode == 200) {
      Uint8List audioBytes = response.bodyBytes;
      await _audioPlayer.play(BytesSource(audioBytes));
    } else {
      print('TTS API error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to generate speech.');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
