import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:mind_speak_app/audio/customesource.dart';
 
class TTSService {
  final String apiKey;
  final AudioPlayer _player = AudioPlayer();
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static const String _voiceId = '21m00Tcm4TlvDq8ikWAM';
  
  final _playerStateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  
  TTSService({required this.apiKey}) {
    // Set up player state listener
    _player.playerStateStream.listen((state) {
      _playerStateController.add(state);
    });
  }
  
  Future<void> speak(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/text-to-speech/$_voiceId'),
        headers: {
          'accept': 'audio/mpeg',
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "text": text,
          "model_id": "eleven_monolingual_v1",
          "voice_settings": {
            "stability": 0.15,
            "similarity_boost": 0.75,
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await _player.stop();
        
        // Create a Completer to handle the ready state
        final readyCompleter = Completer<void>();
        
        StreamSubscription? subscription;
        subscription = _player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.ready) {
            if (!readyCompleter.isCompleted) readyCompleter.complete();
          }
          if (state.processingState == ProcessingState.completed) {
            subscription?.cancel();
          }
        });

        await _player.setAudioSource(CustomAudioSource(response.bodyBytes));
        await readyCompleter.future;
        await _player.play();
      } else {
        throw Exception('TTS API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> stop() async {
    await _player.stop();
  }
  
  void dispose() {
    _player.dispose();
    _playerStateController.close();
  }
}
enum TTSState {
  idle,
  loading,
  speaking,
  error,
}