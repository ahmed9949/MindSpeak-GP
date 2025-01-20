// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';

// // Your local imports:
// import 'package:mind_speak_app/audio/customesource.dart';
// import 'package:mind_speak_app/components/chat_bubble.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsService.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';

// class start_session extends StatefulWidget {
//   const start_session({super.key});

//   @override
//   State<start_session> createState() => _HomePageState();
// }

// class _HomePageState extends State<start_session> {
//   // Services
//   final _sttService = STTService();
//   final _ttsService = TTSService();
//   final _chatService = ChatService();

//   // Audio player
//   final AudioPlayer _player = AudioPlayer();

//   // Chat state
//   List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   // Rive controllers
//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

//   // Conversation session
//   bool _isInSession = false;
//   bool _isProcessingResponse = false;
//   String _currentBuffer = "";

//   @override
//   void initState() {
//     super.initState();
//     _talkController = OneShotAnimation('Talk', autoplay: false);
//     _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
//     _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

//     _initializeApp();
//   }

//   Future<void> _initializeApp() async {
//     try {
//       await _checkPermissions();
//       await _sttService.initialize(
//         onError: (error) {
//           _handleError('Speech error: ${error.errorMsg}');
//           _endConversationSession();
//         },
//         onStatus: (status) {
//           // Handle STT status changes if needed
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final groqKey = dotenv.env['GROQ_API_KEY'];

//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (groqKey == null || groqKey.isEmpty) {
//       _handleError('Groq API key not found in .env file');
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final status = await Permission.microphone.request();
//     if (!status.isGranted) {
//       throw Exception('Microphone permission is required.');
//     }
//   }

//   void _triggerAction(OneShotAnimation controller) {
//     if (!mounted) return;
//     setState(() {
//       _talkController.isActive = false;
//       _hearController.isActive = false;
//       _stopHearController.isActive = false;
//       controller.isActive = true;
//     });
//   }

//   void _startConversationSession() {
//     if (_isInSession) return;
//     setState(() => _isInSession = true);

//     _triggerAction(_hearController);
//     _startContinuousListening();
//   }

//   Future<void> _endConversationSession() async {
//     // 1) Save the conversation to Firestore
//     await _saveSessionToFirestore();

//     // 2) Stop STT and reset
//     await _sttService.stopListening();
//     setState(() {
//       _isInSession = false;
//       _currentBuffer = "";
//       _isProcessingResponse = false;
//     });
//     _triggerAction(_stopHearController);
//   }

//   Future<void> _startContinuousListening() async {
//     if (!_isInSession) return;
//     try {
//       await _sttService.startListening(
//         onResult: (recognizedWords, confidence, isFinal) {
//           if (!mounted || !_isInSession) return;

//           setState(() => _currentBuffer = recognizedWords);

//           if (isFinal && recognizedWords.isNotEmpty) {
//             _processSpeechBuffer();
//           }
//         },
//         listenMode: ListenMode.dictation,
//         partialResults: true,
//       );
//     } catch (e) {
//       _handleError('Continuous listening error: $e');
//       _endConversationSession();
//     }
//   }

//   Future<void> _processSpeechBuffer() async {
//     final textToProcess = _currentBuffer.trim();
//     if (textToProcess.isEmpty || _isProcessingResponse) return;

//     setState(() {
//       _currentBuffer = "";
//       _isProcessingResponse = true;
//     });

//     _addMessage(ChatMessage(text: textToProcess, isUser: true));
//     await _processWithLLM(textToProcess);
//   }

//   Future<void> _processWithLLM(String text) async {
//     // Stop STT so TTS isn't picked up
//     await _sttService.stopListening();

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));

//       // Play TTS
//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     // Restart STT if still in session
//     if (mounted && _isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   Future<void> _playTextToSpeech(String text) async {
//     await _player.stop();

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);

//       await _player.setAudioSource(CustomAudioSource(bytes));

//       final completer = Completer<void>();
//       late final StreamSubscription subscription;
//       subscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return;

//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             // Start "talk" animation
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             // TTS finished
//             _triggerAction(_stopHearController);
//             subscription.cancel();
//             if (!completer.isCompleted) {
//               completer.complete();
//             }
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//       await completer.future;
//     } catch (e) {
//       _handleError('Text-to-speech error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   // -------------------------------------------
//   // SAVE SESSION TO FIRESTORE
//   // -------------------------------------------
//   Future<void> _saveSessionToFirestore() async {
//     try {
//       // Access the SessionProvider (make sure you have set up ChangeNotifierProvider somewhere above)
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;

//       if (childId == null) {
//         debugPrint('No childId found for this user, cannot save session.');
//         return;
//       }

//       // Fetch child doc to get the therapistId (assuming child doc has 'therapistId')
//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         debugPrint('Child document does not exist, cannot save session.');
//         return;
//       }

//       final therapistId = childDoc.data()?['therapistId'] ?? '';

//       // Build a text string from the entire chat
//       // Or store as an array of messages if you prefer
//       final conversationText = _chatHistory.map((msg) {
//         final who = msg.isUser ? 'User' : 'AI';
//         return '$who: ${msg.text}';
//       }).join('\n');

//       // Create a new document in "session" collection
//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'sessionNumforChild': 0, // or increment if needed
//         'conversation': conversationText,
//       });

//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }
//   // -------------------------------------------

//   void _addMessage(ChatMessage message) {
//     setState(() => _chatHistory.add(message));
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   void _handleError(String message) {
//     debugPrint('Error: $message');
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     _sttService.stopListening();
//     _player.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Assistant'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               setState(() => _chatHistory.clear());
//               _endConversationSession();
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 3,
//             child: RiveAnimation.asset(
//               'assets/login_screen_character.riv',
//               controllers: [
//                 _talkController,
//                 _hearController,
//                 _stopHearController
//               ],
//               fit: BoxFit.contain,
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(
//               _isInSession
//                   ? _isProcessingResponse
//                       ? "Thinking..."
//                       : "Listening..."
//                   : "Tap to start conversation",
//               style: const TextStyle(fontSize: 16.0),
//             ),
//           ),
//           // Display partial recognized text
//           if (_currentBuffer.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 'Heard so far: $_currentBuffer',
//                 style: const TextStyle(fontSize: 14.0),
//               ),
//             ),
//           Expanded(
//             flex: 4,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: ListView.builder(
//                 controller: _scrollController,
//                 itemCount: _chatHistory.length,
//                 itemBuilder: (context, index) {
//                   final message = _chatHistory[index];
//                   return ChatBubble(message: message);
//                 },
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: ElevatedButton.icon(
//               onPressed: _isInSession
//                   ? _endConversationSession
//                   : _startConversationSession,
//               icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//               label: Text(_isInSession ? 'End Call' : 'Start Call'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _isInSession ? Colors.red : Colors.green,
//                 foregroundColor: Colors.white,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Your local imports:
import 'package:mind_speak_app/audio/customesource.dart';
import 'package:mind_speak_app/components/chat_bubble.dart';
import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart'; // now calls Gemin AI
import 'package:mind_speak_app/service/speechservice.dart';
import 'package:mind_speak_app/service/ttsService.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class start_session extends StatefulWidget {
  const start_session({super.key});

  @override
  State<start_session> createState() => _HomePageState();
}

class _HomePageState extends State<start_session> {
  // Services
  final _sttService = STTService();
  final _ttsService = TTSService();
  final _chatService = ChatService(); // uses Gemin AI now

  // Audio player
  final AudioPlayer _player = AudioPlayer();

  // Chat state
  List<ChatMessage> _chatHistory = [];
  final ScrollController _scrollController = ScrollController();

  // Rive controllers
  late OneShotAnimation _talkController;
  late OneShotAnimation _hearController;
  late OneShotAnimation _stopHearController;

  // Conversation session
  bool _isInSession = false;
  bool _isProcessingResponse = false;
  String _currentBuffer = "";

  @override
  void initState() {
    super.initState();
    _talkController = OneShotAnimation('Talk', autoplay: false);
    _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
    _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _checkPermissions();
      await _sttService.initialize(
        onError: (error) {
          _handleError('Speech error: ${error.errorMsg}');
          _endConversationSession();
        },
        onStatus: (status) {
          // Handle STT status changes if needed
        },
      );
      _validateApiKeys();
    } catch (e) {
      _handleError('Initialization error: $e');
    }
  }

  void _validateApiKeys() {
    final elApiKey = dotenv.env['EL_API_KEY'];
    final geminApiKey = dotenv.env['GEMIN_API_KEY'];

    if (elApiKey == null || elApiKey.isEmpty) {
      _handleError('ElevenLabs API key not found in .env file');
    }
    if (geminApiKey == null || geminApiKey.isEmpty) {
      _handleError('Gemin AI API key not found in .env file');
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission is required.');
    }
  }

  void _triggerAction(OneShotAnimation controller) {
    if (!mounted) return;
    setState(() {
      _talkController.isActive = false;
      _hearController.isActive = false;
      _stopHearController.isActive = false;
      controller.isActive = true;
    });
  }

  void _startConversationSession() {
    if (_isInSession) return;
    setState(() => _isInSession = true);

    _triggerAction(_hearController);
    _startContinuousListening();
  }

  Future<void> _endConversationSession() async {
    // 1) Save the conversation to Firestore
    await _saveSessionToFirestore();

    // 2) Stop STT and reset
    await _sttService.stopListening();
    setState(() {
      _isInSession = false;
      _currentBuffer = "";
      _isProcessingResponse = false;
    });
    _triggerAction(_stopHearController);
  }

  Future<void> _startContinuousListening() async {
    if (!_isInSession) return;
    try {
      await _sttService.startListening(
        onResult: (recognizedWords, confidence, isFinal) {
          if (!mounted || !_isInSession) return;

          setState(() => _currentBuffer = recognizedWords);

          if (isFinal && recognizedWords.isNotEmpty) {
            _processSpeechBuffer();
          }
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
      );
    } catch (e) {
      _handleError('Continuous listening error: $e');
      _endConversationSession();
    }
  }

  Future<void> _processSpeechBuffer() async {
    final textToProcess = _currentBuffer.trim();
    if (textToProcess.isEmpty || _isProcessingResponse) return;

    setState(() {
      _currentBuffer = "";
      _isProcessingResponse = true;
    });

    _addMessage(ChatMessage(text: textToProcess, isUser: true));
    await _processWithLLM(textToProcess);
  }

  Future<void> _processWithLLM(String text) async {
    // Stop STT so TTS isn't picked up
    await _sttService.stopListening();

    try {
      final response = await _chatService.sendMessageToLLM(text);
      _addMessage(ChatMessage(text: response, isUser: false));

      // Play TTS
      await _playTextToSpeech(response);
    } catch (e) {
      _handleError('LLM processing error: $e');
    }

    // Restart STT if still in session
    if (mounted && _isInSession) {
      setState(() => _isProcessingResponse = false);
      _startContinuousListening();
    }
  }

  Future<void> _playTextToSpeech(String text) async {
    await _player.stop();

    try {
      final bytes = await _ttsService.synthesizeSpeech(text);

      await _player.setAudioSource(CustomAudioSource(bytes));

      final completer = Completer<void>();
      late final StreamSubscription subscription;
      subscription = _player.playerStateStream.listen((playerState) {
        if (!mounted) return;

        switch (playerState.processingState) {
          case ProcessingState.ready:
            // Start "talk" animation
            _triggerAction(_talkController);
            break;
          case ProcessingState.completed:
            // TTS finished
            _triggerAction(_stopHearController);
            subscription.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
            break;
          default:
            break;
        }
      });

      await _player.play();
      await completer.future;
    } catch (e) {
      _handleError('Text-to-speech error: $e');
      _triggerAction(_stopHearController);
    }
  }

  // -------------------------------------------
  // SAVE SESSION TO FIRESTORE
  // -------------------------------------------
  Future<void> _saveSessionToFirestore() async {
    try {
      // Access the SessionProvider (make sure you have set up ChangeNotifierProvider somewhere above)
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessionProvider.childId;

      if (childId == null) {
        debugPrint('No childId found for this user, cannot save session.');
        return;
      }

      // Fetch child doc to get the therapistId (assuming child doc has 'therapistId')
      final childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        debugPrint('Child document does not exist, cannot save session.');
        return;
      }

      final therapistId = childDoc.data()?['therapistId'] ?? '';

      // Build a text string from the entire chat
      final conversationText = _chatHistory.map((msg) {
        final who = msg.isUser ? 'User' : 'AI';
        return '$who: ${msg.text}';
      }).join('\n');

      // Create a new document in "session" collection
      await FirebaseFirestore.instance.collection('session').add({
        'childId': childId,
        'therapistId': therapistId,
        'date': DateTime.now().toIso8601String(),
        'sessionNumforChild': 0, // or increment if needed
        'conversation': conversationText,
      });

      debugPrint('Session saved successfully to Firestore.');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }
  // -------------------------------------------

  void _addMessage(ChatMessage message) {
    setState(() => _chatHistory.add(message));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleError(String message) {
    debugPrint('Error: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _sttService.stopListening();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _chatHistory.clear());
              _endConversationSession();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: RiveAnimation.asset(
              'assets/login_screen_character.riv',
              controllers: [
                _talkController,
                _hearController,
                _stopHearController
              ],
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _isInSession
                  ? _isProcessingResponse
                      ? "Thinking..."
                      : "Listening..."
                  : "Tap to start conversation",
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
          if (_currentBuffer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Heard so far: $_currentBuffer',
                style: const TextStyle(fontSize: 14.0),
              ),
            ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final message = _chatHistory[index];
                  return ChatBubble(message: message);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isInSession
                  ? _endConversationSession
                  : _startConversationSession,
              icon: Icon(_isInSession ? Icons.call_end : Icons.call),
              label: Text(_isInSession ? 'End Call' : 'Start Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isInSession ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
