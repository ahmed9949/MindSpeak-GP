import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart';
import 'package:mind_speak_app/service/speechservice.dart';
import 'package:mind_speak_app/service/ttsService.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class ChatProvider extends ChangeNotifier {
  late final SpeechService speechService;
  late final TTSService ttsService;
  late final LLMService llmService;

  bool isInSession = false;
  bool isSpeaking = false;
  bool isListening = false;
  String currentBuffer = '';
  List<ChatMessage> chatHistory = [];
  bool isProcessingResponse = false;
  
  // Add timeout management
  Timer? _sessionTimer;
  static const sessionTimeout = Duration(minutes: 2);
  
  StreamSubscription? _ttsSubscription;

  ChatProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final elApiKey = dotenv.env['EL_API_KEY'];
    final groqApiKey = dotenv.env['GROQ_API_KEY'];

    if (elApiKey == null || groqApiKey == null) {
      throw Exception('API keys not found in .env file');
    }

    speechService = SpeechService();
    ttsService = TTSService(apiKey: elApiKey);
    llmService = LLMService(apiKey: groqApiKey);

    await speechService.initialize(
      onError: (error) => print('Speech error: ${error.errorMsg}'),
      onStatus: (status) => print('Speech status: $status'),
    );

    // Enhanced TTS state management
    _ttsSubscription = ttsService.playerStateStream.listen((state) {
      isSpeaking = state.playing;
      
      if (state.processingState == ProcessingState.completed) {
        isProcessingResponse = false;
        isSpeaking = false;
        // Add delay before resuming listening
        Future.delayed(const Duration(milliseconds: 500), () {
          if (isInSession && !isProcessingResponse) {
            _startListening();
          }
        });
        notifyListeners();
      }
    });
  }

  Future<void> _startListening() async {
    if (!isInSession || isProcessingResponse || isSpeaking || isListening) return;

    isListening = true;
    notifyListeners();

    await speechService.startListening(
      onResult: _handleSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> startSession() async {
    if (isInSession) return;

    isInSession = true;
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    notifyListeners();

    // Start session timer
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      endSession();
    });

    await _startListening();
  }

  Future<void> endSession() async {
    _sessionTimer?.cancel();
    isInSession = false;
    currentBuffer = '';
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    await speechService.stop();
    await ttsService.stop();
    notifyListeners();
  }

  void _handleSpeechResult(SpeechRecognitionResult result) async {
    if (!isInSession || isProcessingResponse || isSpeaking) return;

    currentBuffer = result.recognizedWords;
    notifyListeners();

    if (result.finalResult && currentBuffer.isNotEmpty) {
      isProcessingResponse = true;
      isListening = false;
      final text = currentBuffer;
      currentBuffer = '';
      notifyListeners();

      try {
        await speechService.stop();
        
        // Reset session timer on valid input
        _sessionTimer?.cancel();
        _sessionTimer = Timer(sessionTimeout, () {
          endSession();
        });

        addMessage(ChatMessage(text: text, isUser: true));
        final response = await llmService.getResponse(text);
        
        // Add small delay before TTS to prevent self-listening
        await Future.delayed(const Duration(milliseconds: 300));
        addMessage(ChatMessage(text: response, isUser: false));
        await ttsService.speak(response);
      } catch (e) {
        print('Error processing speech: $e');
        isProcessingResponse = false;
        isSpeaking = false;
        isListening = false;
        if (isInSession) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _startListening();
          });
        }
      }
    }
  }

  void addMessage(ChatMessage message) {
    chatHistory.add(message);
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _ttsSubscription?.cancel();
    ttsService.dispose();
    super.dispose();
  }
}