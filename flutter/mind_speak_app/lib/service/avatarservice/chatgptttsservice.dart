import 'dart:convert';
import 'dart:math';
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
  try {
    final url = Uri.parse("https://api.openai.com/v1/audio/speech");
    
    print("Sending TTS request for text: \"${text.substring(0, min(30, text.length))}...\"");
    
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
      Uint8List audioBytes = response.bodyBytes;
      await _audioPlayer.play(BytesSource(audioBytes));
      print("Audio playback started");
    } else {
      print('TTS API error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to generate speech: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in speak method: $e');
    throw Exception('TTS service error: $e');
  }
}

 Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
