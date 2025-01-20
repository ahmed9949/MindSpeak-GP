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
  String lastProcessedText = '';

  Timer? _silenceTimer;
  Timer? _inactivityTimer;
  Timer? _restartTimer;
  int _errorCount = 0;
  bool _shouldContinueListening = false;
  
  // Thresholds and delays
  static const _silenceThreshold = 2;
  static const _inactivityThreshold = 30; // Increased from 15
  static const _restartDelay = 800; // Increased from 500
  static const _maxErrorsBeforeReset = 5; // Increased from 3

  StreamSubscription? _ttsSpeakingSubscription;

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
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        if (!error.permanent && error.errorMsg != 'error_speech_timeout') {
          _handleSpeechError(error);
        }
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
        _handleSpeechStatus(status);
      },
    );

    _ttsSpeakingSubscription = ttsService.isSpeakingStream.listen((speaking) {
      isSpeaking = speaking;
      notifyListeners();

      if (!speaking && isInSession && !isProcessingResponse && _shouldContinueListening) {
        _scheduleListeningRestart();
      }
    });
  }

  void _handleSpeechStatus(String status) {
    switch (status) {
      case 'listening':
        isListening = true;
        notifyListeners();
        break;
      case 'notListening':
        isListening = false;
        notifyListeners();
        if (isInSession && !isProcessingResponse && !isSpeaking && _shouldContinueListening) {
          _scheduleListeningRestart();
        }
        break;
      case 'done':
        isListening = false;
        notifyListeners();
        // Only restart if we should continue and not processing or speaking
        if (isInSession && !isProcessingResponse && !isSpeaking && _shouldContinueListening) {
          _scheduleListeningRestart();
        }
        break;
    }
  }

  Future<void> startSession() async {
    if (isInSession) return;

    isInSession = true;
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    currentBuffer = '';
    lastProcessedText = '';
    _errorCount = 0;
    _shouldContinueListening = true;
    notifyListeners();

    _startInactivityTimer();
    await _startContinuousListening();
  }

  Future<void> endSession() async {
    _shouldContinueListening = false;
    _cleanupTimers();
    await speechService.stop();
    
    isInSession = false;
    isProcessingResponse = false;
    isSpeaking = false;
    isListening = false;
    currentBuffer = '';
    lastProcessedText = '';
    _errorCount = 0;
    notifyListeners();
  }

  void _cleanupTimers() {
    _silenceTimer?.cancel();
    _inactivityTimer?.cancel();
    _restartTimer?.cancel();
  }

  void _scheduleListeningRestart() {
    if (!_shouldContinueListening) return;
    
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: _restartDelay), () {
      if (isInSession && !isProcessingResponse && !isSpeaking && _shouldContinueListening) {
        _startContinuousListening();
      }
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _inactivityThreshold), () {
      if (isInSession && !isProcessingResponse && _shouldContinueListening) {
        _checkOnUser();
      }
    });
  }

  Future<void> _checkOnUser() async {
    if (!isInSession || !_shouldContinueListening) return;

    await speechService.stop();
    isProcessingResponse = true;
    notifyListeners();

    try {
      final response = await llmService.getResponse(
        "Are you still there? Please let me know if you want to continue our conversation."
      );

      addMessage(ChatMessage(text: response, isUser: false));
      await ttsService.speak(response);
    } finally {
      isProcessingResponse = false;
      notifyListeners();
      if (isInSession && _shouldContinueListening) {
        _scheduleListeningRestart();
      }
    }
  }

  Future<void> _startContinuousListening() async {
    if (!isInSession || isProcessingResponse || isSpeaking || !_shouldContinueListening) return;

    try {
      // Always stop before starting new session
      await speechService.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      if (!_shouldContinueListening) return; // Check again after delay

      isListening = true;
      notifyListeners();

      await speechService.startListening(
        onResult: _onContinuousSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: Duration(seconds: _silenceThreshold + 1),
      );
    } catch (e) {
      debugPrint('Continuous listening error: $e');
      if (_shouldContinueListening) {
        _attemptRecovery();
      }
    }
  }

  void _onContinuousSpeechResult(SpeechRecognitionResult result) {
    if (!isInSession || isProcessingResponse || isSpeaking || !_shouldContinueListening) return;

    // Reset error count on successful recognition
    if (result.recognizedWords.isNotEmpty) {
      _errorCount = 0;
      
      // Only update buffer if text has changed
      if (result.recognizedWords != currentBuffer) {
        currentBuffer = result.recognizedWords;
        notifyListeners();

        // Reset timers
        _silenceTimer?.cancel();
        _startInactivityTimer();

        // Process immediately if final, otherwise wait for silence
        if (result.finalResult) {
          _processSpeechBuffer();
        } else {
          _silenceTimer = Timer(Duration(seconds: _silenceThreshold), () {
            if (currentBuffer.isNotEmpty && currentBuffer != lastProcessedText) {
              _processSpeechBuffer();
            }
          });
        }
      }
    }
  }

  Future<void> _processSpeechBuffer() async {
    if (!isInSession || isProcessingResponse || currentBuffer.isEmpty || 
        currentBuffer == lastProcessedText || !_shouldContinueListening) return;

    isProcessingResponse = true;
    final textToProcess = currentBuffer;
    lastProcessedText = currentBuffer;
    currentBuffer = '';
    notifyListeners();

    try {
      await speechService.stop();
      
      addMessage(ChatMessage(text: textToProcess, isUser: true));
      final response = await llmService.getResponse(textToProcess);
      addMessage(ChatMessage(text: response, isUser: false));
      await ttsService.speak(response);
    } catch (e) {
      debugPrint('Process speech error: $e');
    } finally {
      if (!_shouldContinueListening) return;
      
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
    } else if (_shouldContinueListening) {
      _attemptRecovery();
    }
  }

  void _attemptRecovery() {
    if (!isInSession || !_shouldContinueListening) return;

    _cleanupTimers();
    
    _restartTimer = Timer(Duration(milliseconds: _restartDelay), () async {
      if (!isInSession || !_shouldContinueListening) return;

      try {
        await speechService.stop();
        await _startContinuousListening();
      } catch (e) {
        debugPrint('Recovery failed: $e');
        if (_shouldContinueListening) {
          endSession();
        }
      }
    });
  }

  void addMessage(ChatMessage message) {
    chatHistory.add(message);
    debugPrint('Displaying message: ${message.text}');
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupTimers();
    _ttsSpeakingSubscription?.cancel();
    ttsService.dispose();
    super.dispose();
  }
}