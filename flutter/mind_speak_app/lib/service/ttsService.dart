import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:mind_speak_app/audio/customesource.dart';

class TTSService {
  final String apiKey;
  final AudioPlayer _player = AudioPlayer();
  final StreamController<bool> _isSpeakingController =
      StreamController<bool>.broadcast();

  static const String _baseUrl = 'https://api.elevenlabs.io/v1';
  static const String _voiceId = '21m00Tcm4TlvDq8ikWAM';
  Stream<PlayerState> get playerState => _player.playerStateStream;
  bool get isPlaying => _player.playing;
  // Expose the stream for external listeners
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;
  TTSService({required this.apiKey});
  bool get isProcessing =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  Future<void> speak(String text) async {
    try {
      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await _player.stop();

        // Notify that speaking has started
        _isSpeakingController.add(true);

        await _player.setAudioSource(CustomAudioSource(response.bodyBytes));
        await _player.play();

        // Listen for playback completion
        _player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            // Notify that speaking has ended
            _isSpeakingController.add(false);
          }
        });
      } else {
        throw Exception('TTS API error: ${response.statusCode}');
      }
    } catch (e) {
      _isSpeakingController
          .add(false); // Ensure speaking state is reset on error
      rethrow;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isSpeakingController.add(false); // Notify that speaking has stopped
  }

  void dispose() {
    _isSpeakingController.close();
    _player.dispose();
  }
}
