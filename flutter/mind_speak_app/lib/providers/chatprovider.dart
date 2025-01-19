import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart';
import 'package:mind_speak_app/service/speechservice.dart';
import 'package:mind_speak_app/service/ttsservice.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class ChatProvider extends ChangeNotifier {
  late final SpeechService speechService;
  late final TTSService ttsService;
  late final LLMService llmService;

  bool isInSession = false;
  bool isSpeaking = false;
  bool isListening = false;
  bool isProcessingResponse = false;
  String currentBuffer = '';
  List<ChatMessage> chatHistory = [];

  Timer? _silenceTimer;
  Timer? _restartTimer;
  int _errorCount = 0;
  bool _hasFinalResult = false;
  String _lastProcessedText = '';

  static const _restartDelay = 800; // ms
  static const _silenceThreshold = 1500; // ms
  static const _maxErrorsBeforeReset = 3;

  StreamSubscription? _ttsSpeakingSubscription;

//   ChatProvider() {
//     _initializeServices();
//   }

//   Future<void> _initializeServices() async {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final groqApiKey = dotenv.env['GROQ_API_KEY'];

//     if (elApiKey == null || groqApiKey == null) {
//       throw Exception('API keys not found in .env file');
//     }

//     speechService = SpeechService();
//     ttsService = TTSService(apiKey: elApiKey);
//     llmService = LLMService(apiKey: groqApiKey);

    await speechService.initialize(
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        if (error.errorMsg != 'error_speech_timeout' && error.errorMsg != 'error_busy') {
          _handleSpeechError(error);
        }
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' && isInSession && !isProcessingResponse && !isSpeaking) {
          _checkAndProcessFinalResult();
        }
      },
    );

    _ttsSpeakingSubscription = ttsService.isSpeakingStream.listen((speaking) {
      isSpeaking = speaking;
      notifyListeners();

      if (!speaking && isInSession && !isProcessingResponse) {
        _scheduleListeningRestart();
      }
    });
  }

  void _checkAndProcessFinalResult() {
    if (!_hasFinalResult && currentBuffer.isNotEmpty && currentBuffer != _lastProcessedText) {
      _processSpeechBuffer(currentBuffer);
    }
    _scheduleListeningRestart();
  }

  void _scheduleListeningRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: _restartDelay), () {
      if (isInSession && !isProcessingResponse && !isSpeaking) {
        _startListening();
      }
    });
  }

//   Future<void> startSession() async {
//     if (isInSession) return;

    isInSession = true;
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    currentBuffer = '';
    _lastProcessedText = '';
    _hasFinalResult = false;
    _errorCount = 0;
    notifyListeners();

    await _startListening();
  }

  Future<void> endSession() async {
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    await speechService.stop();
    
    isInSession = false;
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    currentBuffer = '';
    _lastProcessedText = '';
    _hasFinalResult = false;
    _errorCount = 0;
    notifyListeners();
  }

  Future<void> _startListening() async {
    if (!isInSession || isProcessingResponse || isSpeaking) return;

    try {
      // Stop any existing listening session
      await speechService.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      isListening = true;
      _hasFinalResult = false;
      notifyListeners();

      await speechService.startListening(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Start listening error: $e');
      _handleSpeechError(e);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!isInSession || isProcessingResponse || isSpeaking) return;

    bool isFinal = result.finalResult;
    String text = result.recognizedWords;

    // Only update buffer if we have text
    if (text.isNotEmpty) {
      currentBuffer = text;
      notifyListeners();

      // Reset silence timer
      _silenceTimer?.cancel();

      if (isFinal) {
        _hasFinalResult = true;
        _processSpeechBuffer(text);
      } else {
        // Set timer for processing partial results after silence
        _silenceTimer = Timer(Duration(milliseconds: _silenceThreshold), () {
          if (!_hasFinalResult && currentBuffer.isNotEmpty && currentBuffer != _lastProcessedText) {
            _processSpeechBuffer(currentBuffer);
          }
        });
      }
    }
  }

  Future<void> _processSpeechBuffer(String text) async {
    if (!isInSession || isProcessingResponse || text.isEmpty || text == _lastProcessedText) return;

    isProcessingResponse = true;
    _lastProcessedText = text;
    currentBuffer = '';
    notifyListeners();

    try {
      await speechService.stop();
      
      addMessage(ChatMessage(text: text, isUser: true));
      final response = await llmService.getResponse(text);
      addMessage(ChatMessage(text: response, isUser: false));
      await ttsService.speak(response);
    } catch (e) {
      debugPrint('Process speech error: $e');
    } finally {
      isProcessingResponse = false;
      notifyListeners();
      
      if (isInSession && !isSpeaking) {
        _scheduleListeningRestart();
      }
    }
  }

  void _handleSpeechError(dynamic error) {
    debugPrint('Speech error: $error');
    _errorCount++;

    if (_errorCount >= _maxErrorsBeforeReset) {
      endSession();
    } else {
      _scheduleListeningRestart();
    }
  }

  void addMessage(ChatMessage message) {
    chatHistory.add(message);
    debugPrint('Displaying message: ${message.text}');
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _ttsSpeakingSubscription?.cancel();
    ttsService.dispose();
    super.dispose();
  }
}