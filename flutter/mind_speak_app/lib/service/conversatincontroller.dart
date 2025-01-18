import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart';
 import 'package:mind_speak_app/service/speechservice.dart';
import 'package:mind_speak_app/service/ttsservice.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

 

class ConversationController {
  final SpeechService speechService;
  final TTSService ttsService;
  final LLMService llmService;
  
  bool isInSession = false;
  String currentBuffer = '';
  List<ChatMessage> chatHistory = [];
  
  final void Function(String) onError;
  final void Function() onStateChanged;
  
  ConversationController({
    required this.speechService,
    required this.ttsService,
    required this.llmService,
    required this.onError,
    required this.onStateChanged,
  });
  
  Future<void> startSession() async {
    if (isInSession) return;
    
    try {
      isInSession = true;
      onStateChanged();
      await _startListening();
    } catch (e) {
      onError(e.toString());
      endSession();
    }
  }
  
  Future<void> endSession() async {
    isInSession = false;
    currentBuffer = '';
    await speechService.stop();
    await ttsService.stop();
    onStateChanged();
  }
  
  Future<void> _startListening() async {
    await speechService.startListening(
      onResult: _handleSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }
  
  void _handleSpeechResult(SpeechRecognitionResult result) async {
    currentBuffer = result.recognizedWords;
    onStateChanged();
    
    if (result.finalResult && currentBuffer.isNotEmpty) {
      final text = currentBuffer;
      currentBuffer = '';
      onStateChanged();
      
      _addMessage(ChatMessage(text: text, isUser: true));
      
      try {
        final response = await llmService.getResponse(text);
        _addMessage(ChatMessage(text: response, isUser: false));
        await ttsService.speak(response);
      } catch (e) {
        onError(e.toString());
      }
    }
  }
  
  void _addMessage(ChatMessage message) {
    chatHistory.add(message);
    onStateChanged();
  }
}
