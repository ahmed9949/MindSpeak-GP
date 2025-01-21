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

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';

// import 'package:mind_speak_app/audio/customesource.dart';
// import 'package:mind_speak_app/components/chat_bubble.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsService.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';

// class start_session extends StatefulWidget {
//   const start_session({Key? key}) : super(key: key);

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
//   // We'll keep a reference to our subscription so we can cancel in dispose
//   StreamSubscription<PlayerState>? _playerSubscription;

//   // Chat state
//   final List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   // Rive controllers
//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

//   // Flags
//   bool _isInSession = false;
//   bool _isProcessingResponse = false;
//   String _currentBuffer = "";

//   @override
//   void initState() {
//     super.initState();
//     // Rive animations
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
//           // If needed, handle STT status changes here
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final geminiKey = dotenv.env['GEMINI_API_KEY'];
//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (geminiKey == null || geminiKey.isEmpty) {
//       _handleError('Gemini AI API key not found in .env file');
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final status = await Permission.microphone.request();
//     if (!status.isGranted) {
//       throw Exception('Microphone permission is required.');
//     }
//   }

//   // Trigger a single Rive animation
//   void _triggerAction(OneShotAnimation controller) {
//     if (!mounted) return;
//     setState(() {
//       _talkController.isActive = false;
//       _hearController.isActive = false;
//       _stopHearController.isActive = false;
//       controller.isActive = true;
//     });
//   }

//   // Start session
//   void _startConversationSession() {
//     if (_isInSession) return;
//     setState(() => _isInSession = true);

//     // "Hear" animation
//     _triggerAction(_hearController);
//     _startContinuousListening();
//   }

//   // End session
//   Future<void> _endConversationSession() async {
//     // Save conversation
//     await _saveSessionToFirestore();

//     // Stop STT
//     await _sttService.stopListening();
//     if (!mounted) return;

//     setState(() {
//       _isInSession = false;
//       _currentBuffer = "";
//       _isProcessingResponse = false;
//     });

//     _triggerAction(_stopHearController);
//   }

//   // Continuous STT
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

//   // Called once STT finalizes text
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

//   // LLM call + TTS
//   // We stop STT to avoid self-echo, then TTS, then resume STT.
//   Future<void> _processWithLLM(String text) async {
//     // Stop STT so it doesn't hear TTS
//     await _sttService.stopListening();

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));

//       // TTS
//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     // Resume STT for next user input
//     if (!mounted) return;
//     if (_isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   // TTS
//   Future<void> _playTextToSpeech(String text) async {
//     // Cancel old subscription if any
//     await _player.stop();
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);
//       await _player.setAudioSource(CustomAudioSource(bytes));

//       // Listen for player events
//       _playerSubscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return; // if widget gone, do nothing

//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             // Start "talk" animation
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             // TTS finished
//             _triggerAction(_stopHearController);
//             _playerSubscription?.cancel();
//             _playerSubscription = null;
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//     } catch (e) {
//       _handleError('Text-to-speech error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   // If user hits "Interrupt" button: forcibly stop TTS
//   // Then optionally resume STT
//   void _interruptSpeech() async {
//     // Stop the player
//     await _player.stop();
//     if (!mounted) return;

//     // If we want to keep listening
//     if (_isInSession) {
//       _triggerAction(_hearController);
//       setState(() => _isProcessingResponse = false);
//       // STT may be off if we had just started TTS => so re-start
//       _startContinuousListening();
//     }
//   }

//   // Save session to Firestore
//   Future<void> _saveSessionToFirestore() async {
//     try {
//       final sessionProvider =
//           Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;
//       if (childId == null) {
//         debugPrint('No childId found, cannot save session.');
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();
//       if (!childDoc.exists) {
//         debugPrint('Child doc does not exist.');
//         return;
//       }

//       final therapistId = childDoc.data()?['therapistId'] ?? '';

//       final conversationText = _chatHistory.map((m) {
//         final who = m.isUser ? 'User' : 'AI';
//         return '$who: ${m.text}';
//       }).join('\n');

//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'sessionNumforChild': 0, // or increment
//         'conversation': conversationText,
//       });
//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }

//   // Add message to chat
//   void _addMessage(ChatMessage message) {
//     if (!mounted) return;
//     setState(() => _chatHistory.add(message));
//     // Auto-scroll
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (!mounted) return;
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
//     // Cancel subscription to avoid setState() after dispose
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     // Stop STT, TTS
//     _sttService.stopListening();
//     _player.dispose();

//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // **Fix overflow** by adding Expanded or flexible layout
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Assistant'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               // Clear chat & end session
//               setState(() => _chatHistory.clear());
//               _endConversationSession();
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // RIVE animation - wrap in a flexible to avoid overflow
//           Flexible(
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

//           // Status text
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

//           // Show partial recognized text
//           if (_currentBuffer.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 'Heard so far: $_currentBuffer',
//                 style: const TextStyle(fontSize: 14.0),
//               ),
//             ),

//           // Chat area
//           Expanded(
//             flex: 4,
//             child: Container(
//               color: Colors.grey[100],
//               child: ListView.builder(
//                 controller: _scrollController,
//                 itemCount: _chatHistory.length,
//                 itemBuilder: (context, index) {
//                   final msg = _chatHistory[index];
//                   return ChatBubble(message: msg);
//                 },
//               ),
//             ),
//           ),

//           // Buttons
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 // Start / End
//                 ElevatedButton.icon(
//                   onPressed: _isInSession
//                       ? _endConversationSession
//                       : _startConversationSession,
//                   icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//                   label: Text(_isInSession ? 'End Call' : 'Start Call'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isInSession ? Colors.red : Colors.green,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 24,
//                       vertical: 12,
//                     ),
//                   ),
//                 ),

//                 // Interrupt TTS
//                 if (_isInSession)
//                   ElevatedButton.icon(
//                     onPressed: _interruptSpeech,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Interrupt'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 24,
//                         vertical: 12,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';

// import 'package:mind_speak_app/audio/customesource.dart';
// import 'package:mind_speak_app/components/chat_bubble.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsService.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';

// class start_session extends StatefulWidget {
//   const start_session({Key? key}) : super(key: key);

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
//   StreamSubscription<PlayerState>? _playerSubscription;

//   // Chat state
//   List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   // Rive controllers
//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

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
//           // handle STT status if needed
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final geminiKey = dotenv.env['GEMINI_API_KEY'];
//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (geminiKey == null || geminiKey.isEmpty) {
//       _handleError('Gemini AI API key not found in .env file');
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

//   // --------------------------------------------------
//   //  START SESSION: Fetch child data, welcome them
//   // --------------------------------------------------
//   void _startConversationSession() async {
//     if (_isInSession) return;
//     setState(() => _isInSession = true);

//     // Show "hearing" animation
//     _triggerAction(_hearController);

//     // 1) Get child's name (or other data) from Firestore
//     final childName = await _fetchChildName();
//     // Fallback if missing
//     final displayName = childName.isEmpty ? 'there' : childName;

//     // 2) Make a welcome message
//     final welcomeText = "Hello $displayName! I'm glad you're here. "
//         "What do you want to talk about today?";

//     // 3) Add it as an AI message
//     _addMessage(ChatMessage(text: welcomeText, isUser: false));

//     // 4) Speak it out loud
//     //    Optionally, you might want to keep STT on if you want
//     //    voice interruption, but let's do the typical approach: stop->tts->start
//     await _sttService.stopListening(); // stop so we don't pick up our own TTS
//     await _playTextToSpeech(welcomeText);

//     // 5) Now start indefinite STT listening
//     _startContinuousListening();
//   }

//   // Helper to fetch the child's name from Firestore
//   Future<String> _fetchChildName() async {
//     try {
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;
//       if (childId == null) {
//         debugPrint("No childId in session, can't fetch name.");
//         return '';
//       }
//       final childSnap = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();
//       if (!childSnap.exists) return '';

//       // Suppose the child's Firestore doc has a field "name"
//       final data = childSnap.data();
//       final name = data?['name'] ?? '';
//       return name.toString();
//     } catch (e) {
//       debugPrint("Error fetching child's name: $e");
//       return '';
//     }
//   }
//   // --------------------------------------------------

//   // End session
//   Future<void> _endConversationSession() async {
//     // Save conversation to Firestore
//     await _saveSessionToFirestore();

//     // Stop STT
//     await _sttService.stopListening();
//     if (!mounted) return;

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
//     await _sttService.stopListening(); // avoid self-echo

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));

//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     if (!mounted) return;
//     if (_isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   Future<void> _playTextToSpeech(String text) async {
//     await _player.stop();
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);
//       await _player.setAudioSource(CustomAudioSource(bytes));

//       _playerSubscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return;

//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             _triggerAction(_stopHearController);
//             _playerSubscription?.cancel();
//             _playerSubscription = null;
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//     } catch (e) {
//       _handleError('Text-to-speech error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   void _interruptSpeech() async {
//     await _player.stop();
//     if (!mounted) return;

//     if (_isInSession) {
//       _triggerAction(_hearController);
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   Future<void> _saveSessionToFirestore() async {
//     try {
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;
//       if (childId == null) {
//         debugPrint('No childId found, cannot save session.');
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();
//       if (!childDoc.exists) return;

//       final therapistId = childDoc.data()?['therapistId'] ?? '';

//       final conversationText = _chatHistory.map((m) {
//         final who = m.isUser ? 'User' : 'AI';
//         return '$who: ${m.text}';
//       }).join('\n');

//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'sessionNumforChild': 0,
//         'conversation': conversationText,
//       });
//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }

//   void _addMessage(ChatMessage message) {
//     if (!mounted) return;
//     setState(() => _chatHistory.add(message));
//     // Auto-scroll
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (!mounted) return;
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
//     _playerSubscription?.cancel();
//     _playerSubscription = null;
//     _sttService.stopListening();
//     _player.dispose();
//     _scrollController.dispose();
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
//           Flexible(
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
//               color: Colors.grey[100],
//               child: ListView.builder(
//                 controller: _scrollController,
//                 itemCount: _chatHistory.length,
//                 itemBuilder: (context, index) {
//                   final msg = _chatHistory[index];
//                   return ChatBubble(message: msg);
//                 },
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isInSession
//                       ? _endConversationSession
//                       : _startConversationSession,
//                   icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//                   label: Text(_isInSession ? 'End Call' : 'Start Call'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isInSession ? Colors.red : Colors.green,
//                     foregroundColor: Colors.white,
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//                 if (_isInSession)
//                   ElevatedButton.icon(
//                     onPressed: _interruptSpeech,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Interrupt'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                       padding:
//                           const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:camera/camera.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';

// // Local imports
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
//   State<start_session> createState() => _StartSessionState();
// }

// class _StartSessionState extends State<start_session> {
//   // ------------------ CAMERA FIELDS ------------------
//   CameraController? _cameraController;
//   Timer? _cameraTimer;
//   bool _isProcessingImage = false;
//   String _emotion = "No emotion detected yet";

//   // Tweak to match your backend’s IP:port
//   final String _backendUrl = "http://192.168.1.17:5000/emotion-detection";

//   // ------------------ AUDIO / CHAT FIELDS ------------------
//   final _sttService = STTService();
//   final _ttsService = TTSService();
//   final _chatService = ChatService();

//   final AudioPlayer _player = AudioPlayer();

//   List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

//   bool _isInSession = false;
//   bool _isProcessingResponse = false;
//   String _currentBuffer = "";

//   // We store the TTS subscription so we can cancel in dispose
//   StreamSubscription<PlayerState>? _playerSubscription;

//   @override
//   void initState() {
//     super.initState();

//     // Rive animations
//     _talkController = OneShotAnimation('Talk', autoplay: false);
//     _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
//     _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

//     _initializeApp();     // STT init, permission checks, etc.
//     _initializeCamera();  // Camera init for emotion detection
//   }

//   // ------------------ CAMERA INIT ------------------
//   Future<void> _initializeCamera() async {
//     try {
//       // 1) Get list of cameras
//       final cameras = await availableCameras();

//       // 2) Pick the front camera
//       final frontCamera = cameras.firstWhere(
//           (cam) => cam.lensDirection == CameraLensDirection.front);

//       // 3) Create a controller
//       _cameraController = CameraController(
//         frontCamera,
//         ResolutionPreset.medium,
//         enableAudio: false, // We only need video frames
//       );

//       // 4) Initialize
//       await _cameraController!.initialize();
//       setState(() {});

//       // 5) Start periodic frame capture
//       _startFrameCapture();
//     } catch (e) {
//       debugPrint("Error initializing camera: $e");
//     }
//   }

//   // Periodically capture frames
//   void _startFrameCapture() {
//     _cameraTimer?.cancel();
//     // For example, every 5 seconds (instead of every 1s) to reduce load
//     _cameraTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//       _captureAndDetectEmotion();
//     });
//   }

//   // Stop the camera timer if needed
//   void _stopFrameCapture() {
//     _cameraTimer?.cancel();
//     _cameraTimer = null;
//   }

//   // Capture a frame, send to backend
//   Future<void> _captureAndDetectEmotion() async {
//     if (_cameraController == null ||
//         !_cameraController!.value.isInitialized ||
//         _isProcessingImage) {
//       return;
//     }

//     setState(() => _isProcessingImage = true);

//     try {
//       final XFile file = await _cameraController!.takePicture();
//       final Uint8List imageBytes = await file.readAsBytes();

//       await _sendImageToBackend(imageBytes);
//     } catch (e) {
//       debugPrint("Error capturing emotion: $e");
//       setState(() {
//         _emotion = "Error capturing emotion: $e";
//       });
//     } finally {
//       if (mounted) {
//         setState(() => _isProcessingImage = false);
//       }
//     }
//   }

//   // Actually call the Flask backend
//   Future<void> _sendImageToBackend(Uint8List imageBytes) async {
//     try {
//       final request = http.MultipartRequest("POST", Uri.parse(_backendUrl));
//       request.files.add(http.MultipartFile.fromBytes(
//         "frame",
//         imageBytes,
//         filename: "frame.jpg",
//       ));

//       final response = await request.send();

//       if (response.statusCode == 200) {
//         final responseData = await response.stream.bytesToString();
//         final decodedData = jsonDecode(responseData);
//         final detectedEmotion = decodedData['emotion'];
//         debugPrint("Emotion detected: $detectedEmotion");
//         if (mounted) {
//           setState(() => _emotion = detectedEmotion);
//         }
//       } else {
//         if (mounted) {
//           setState(() => _emotion = "Failed to detect emotion");
//         }
//       }
//     } catch (e) {
//       debugPrint("Error sending image: $e");
//       if (mounted) {
//         setState(() => _emotion = "Error: $e");
//       }
//     }
//   }

//   // ------------------ AUDIO/STT INIT ------------------
//   Future<void> _initializeApp() async {
//     try {
//       await _checkPermissions();
//       await _sttService.initialize(
//         onError: (error) {
//           _handleError('Speech error: ${error.errorMsg}');
//           _endConversationSession();
//         },
//         onStatus: (status) {
//           // handle STT status changes if needed
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final geminApiKey = dotenv.env['GEMINI_API_KEY'];

//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (geminApiKey == null || geminApiKey.isEmpty) {
//       _handleError('Gemini AI API key not found in .env file');
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final micStatus = await Permission.microphone.request();
//     if (!micStatus.isGranted) {
//       throw Exception('Microphone permission is required.');
//     }
//     // If your camera permission wasn't automatically granted, do:
//     final camStatus = await Permission.camera.request();
//     if (!camStatus.isGranted) {
//       throw Exception('Camera permission is required.');
//     }
//   }

//   // ------------------ START / END SESSION ------------------
//   void _startConversationSession() {
//     if (_isInSession) return;
//     setState(() => _isInSession = true);

//     _triggerAction(_hearController);
//     _startContinuousListening();
//   }

//   Future<void> _endConversationSession() async {
//     // Save session to Firestore
//     await _saveSessionToFirestore();

//     // Stop STT
//     await _sttService.stopListening();
//     setState(() {
//       _isInSession = false;
//       _currentBuffer = "";
//       _isProcessingResponse = false;
//     });

//     _triggerAction(_stopHearController);
//   }

//   // ------------------ STT LOOP ------------------
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

//   // ------------------ LLM + TTS ------------------
//   Future<void> _processWithLLM(String text) async {
//     // Stop STT to avoid self-echo
//     await _sttService.stopListening();

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));
//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     if (mounted && _isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }
// void _triggerAction(OneShotAnimation controller) {
//     if (!mounted) return;
//     setState(() {
//       _talkController.isActive = false;
//       _hearController.isActive = false;
//       _stopHearController.isActive = false;
//       controller.isActive = true;
//     });
//   }
//   Future<void> _playTextToSpeech(String text) async {
//     // Stop existing playback
//     await _player.stop();
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);
//       await _player.setAudioSource(CustomAudioSource(bytes));

//       // Subscribe to player events
//       _playerSubscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return;
//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             _triggerAction(_stopHearController);
//             _playerSubscription?.cancel();
//             _playerSubscription = null;
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//     } catch (e) {
//       _handleError('Text-to-speech error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   // If user presses “Interrupt”:
//   void _interruptSpeech() async {
//     await _player.stop();
//     if (!mounted) return;

//     if (_isInSession) {
//       // Return to "hear" state
//       _triggerAction(_hearController);
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   // ------------------ FIRESTORE SESSION SAVE ------------------
//   Future<void> _saveSessionToFirestore() async {
//     try {
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;

//       if (childId == null) {
//         debugPrint('No childId found, cannot save session.');
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         debugPrint('Child doc does not exist, cannot save session.');
//         return;
//       }

//       final therapistId = childDoc.data()?['therapistId'] ?? '';
//       final conversationText = _chatHistory.map((m) {
//         final who = m.isUser ? 'User' : 'AI';
//         return '$who: ${m.text}';
//       }).join('\n');

//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'sessionNumforChild': 0,
//         'conversation': conversationText,
//       });
//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }

//   // ------------------ UTILITY ------------------
//   void _addMessage(ChatMessage message) {
//     setState(() => _chatHistory.add(message));
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (!mounted) return;
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
//     // Cancel camera timer
//     _stopFrameCapture();

//     // Dispose camera
//     _cameraController?.dispose();

//     // Cancel audio subscription
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     // Stop STT
//     _sttService.stopListening();

//     // Dispose player
//     _player.dispose();

//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Assistant with Emotion Detection'),
//       ),
//       body: Column(
//         children: [
//           // 1) CAMERA PREVIEW
//           if (_cameraController != null && _cameraController!.value.isInitialized)
//             AspectRatio(
//               aspectRatio: _cameraController!.value.aspectRatio,
//               child: CameraPreview(_cameraController!),
//             )
//           else
//             Container(
//               height: 200,
//               color: Colors.black12,
//               child: const Center(child: Text("Camera not available")),
//             ),

//           // 2) CURRENT EMOTION
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 8.0),
//             child: Text(
//               "Detected Emotion: $_emotion",
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),

//           // 3) RIVE ANIMATION
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

//           // 4) Status text
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

//           // 5) Show partial recognized text
//           if (_currentBuffer.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 'Heard so far: $_currentBuffer',
//                 style: const TextStyle(fontSize: 14.0),
//               ),
//             ),

//           // 6) Chat messages
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

//           // 7) Buttons
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isInSession
//                       ? _endConversationSession
//                       : _startConversationSession,
//                   icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//                   label: Text(_isInSession ? 'End Call' : 'Start Call'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isInSession ? Colors.red : Colors.green,
//                     foregroundColor: Colors.white,
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//                 if (_isInSession)
//                   ElevatedButton.icon(
//                     onPressed: _interruptSpeech,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Interrupt'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                       padding:
//                           const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;

// // Local imports
// import 'package:mind_speak_app/audio/customesource.dart';
// import 'package:mind_speak_app/components/chat_bubble.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsService.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';

// class start_session extends StatefulWidget {
//   const start_session({Key? key}) : super(key: key);

//   @override
//   State<start_session> createState() => _StartSessionState();
// }

// class _StartSessionState extends State<start_session> {
//   // ------------------ CAMERA & DETECTION FIELDS ------------------
//   CameraController? _cameraController;
//   Timer? _detectionTimer;
//   bool _isDetecting = false; // True while session is active

//   // We track how many frames total, plus counts & changes for behavior/emotion
//   int _totalFrames = 0;

//   // Behavior tracking
//   final Map<String, int> _behaviorCounts = {};
//   String _lastBehavior = '';
//   int _behaviorChanges = 0;

//   // Emotion tracking
//   final Map<String, int> _emotionCounts = {};
//   String _lastEmotion = '';
//   int _emotionChanges = 0;

//   // The backend endpoint:
//   final String _analysisUrl = 'http://192.168.1.17:5000/analyze_frame';

//   // ------------------ AUDIO / CHAT FIELDS ------------------
//   final _sttService = STTService();
//   final _ttsService = TTSService();
//   final _chatService = ChatService();

//   final AudioPlayer _player = AudioPlayer();
//   StreamSubscription<PlayerState>? _playerSubscription;

//   List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

//   bool _isInSession = false;
//   bool _isProcessingResponse = false;
//   String _currentBuffer = "";

//   @override
//   void initState() {
//     super.initState();
//     // Rive animations
//     _talkController = OneShotAnimation('Talk', autoplay: false);
//     _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
//     _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

//     _initializeApp();     // STT init & permission checks
//     _initializeCamera();  // Set up camera for detection
//   }

//   // ------------------ APP INIT (STT, PERMISSIONS) ------------------
//   Future<void> _initializeApp() async {
//     try {
//       await _checkPermissions();
//       await _sttService.initialize(
//         onError: (error) {
//           _handleError('Speech error: ${error.errorMsg}');
//           _endConversationSession();
//         },
//         onStatus: (status) {
//           // handle STT status changes if needed
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final geminiKey = dotenv.env['GEMINI_API_KEY'];

//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (geminiKey == null || geminiKey.isEmpty) {
//       _handleError('Gemini AI API key not found in .env file');
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final micStatus = await Permission.microphone.request();
//     if (!micStatus.isGranted) {
//       throw Exception('Microphone permission is required.');
//     }
//     final camStatus = await Permission.camera.request();
//     if (!camStatus.isGranted) {
//       throw Exception('Camera permission is required.');
//     }
//   }

//   // ------------------ CAMERA INIT ------------------
//   Future<void> _initializeCamera() async {
//     try {
//       // 1) Gather cameras
//       final cameras = await availableCameras();
//       // 2) Pick the front camera
//       final frontCamera = cameras.firstWhere(
//         (cam) => cam.lensDirection == CameraLensDirection.front,
//       );

//       // 3) Create & init the controller
//       _cameraController = CameraController(
//         frontCamera,
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );
//       await _cameraController!.initialize();
//       setState(() {});

//       // We do NOT start detection yet. We'll wait for session start.
//     } catch (e) {
//       debugPrint('Error initializing camera: $e');
//     }
//   }

//   // ------------------ START / STOP DETECTION ------------------
//   void _startDetectionLoop() {
//     if (_cameraController == null ||
//         !_cameraController!.value.isInitialized ||
//         _isDetecting) {
//       return;
//     }
//     _isDetecting = true;
//     _totalFrames = 0;
//     _behaviorCounts.clear();
//     _behaviorChanges = 0;
//     _lastBehavior = '';

//     _emotionCounts.clear();
//     _emotionChanges = 0;
//     _lastEmotion = '';

//     // For example, capture every 5 seconds
//     _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//       _captureFrameForAnalysis();
//     });
//   }

//   void _stopDetectionLoop() {
//     _detectionTimer?.cancel();
//     _detectionTimer = null;
//     _isDetecting = false;
//   }

//   Future<void> _captureFrameForAnalysis() async {
//     if (!_isDetecting) return;
//     try {
//       final XFile file = await _cameraController!.takePicture();
//       final Uint8List bytes = await file.readAsBytes();
//       await _analyzeFrame(bytes);
//     } catch (e) {
//       debugPrint('Error capturing frame: $e');
//     }
//   }

//   Future<void> _analyzeFrame(Uint8List imageBytes) async {
//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(_analysisUrl));
//       request.files.add(
//         http.MultipartFile.fromBytes('frame', imageBytes, filename: 'frame.jpg'),
//       );
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final behavior = data['behavior'] ?? '';
//         final emotion = data['emotion'] ?? '';

//         // Keep track
//         _totalFrames++;

//         // Behavior
//         if (behavior.isNotEmpty) {
//           _behaviorCounts[behavior] = (_behaviorCounts[behavior] ?? 0) + 1;
//           if (_lastBehavior.isNotEmpty && _lastBehavior != behavior) {
//             _behaviorChanges++;
//           }
//           _lastBehavior = behavior;
//         }

//         // Emotion
//         if (emotion.isNotEmpty) {
//           _emotionCounts[emotion] = (_emotionCounts[emotion] ?? 0) + 1;
//           if (_lastEmotion.isNotEmpty && _lastEmotion != emotion) {
//             _emotionChanges++;
//           }
//           _lastEmotion = emotion;
//         }
//       } else {
//         debugPrint('Server error: ${response.body}');
//       }
//     } catch (e) {
//       debugPrint('Error analyzing frame: $e');
//     }
//   }

//   // ------------------ WELCOME MESSAGE (Child data) ------------------
//   Future<void> _autoWelcomeChild() async {
//     try {
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;
//       if (childId == null) {
//         await _processWithLLM("Hello there! How can I help you today?");
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         await _processWithLLM("Hello there! How can I help you today?");
//         return;
//       }

//       final data = childDoc.data()!;
//       final childName = data['name'] ?? 'friend';
//       final welcomePrompt =
//         "Hello $childName! I'm here to chat with you. "
//         "What are some of your favorite things to do or learn about?";

//       await _processWithLLM(welcomePrompt);

//     } catch (e) {
//       debugPrint("Error in _autoWelcomeChild: $e");
//       await _processWithLLM("Hello! I'm here to help you today.");
//     }
//   }

//   // ------------------ START / END SESSION  ------------------
//   void _startConversationSession() async {
//     if (_isInSession) return;
//     setState(() => _isInSession = true);

//     // 1) Send a welcome message based on child data
//     await _autoWelcomeChild();

//     // 2) Start detection
//     _startDetectionLoop();

//     // 3) Start STT
//     _triggerAction(_hearController);
//     _startContinuousListening();
//   }

//   Future<void> _endConversationSession() async {
//     // 1) Stop detection
//     _stopDetectionLoop();

//     // 2) Save session
//     await _saveSessionToFirestore();

//     // 3) Stop STT
//     await _sttService.stopListening();
//     setState(() {
//       _isInSession = false;
//       _currentBuffer = "";
//       _isProcessingResponse = false;
//     });

//     _triggerAction(_stopHearController);
//   }

//   // ------------------ STT LOOP ------------------
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

//   // ------------------ LLM + TTS ------------------
//   Future<void> _processWithLLM(String text) async {
//     // Stop STT so TTS isn't picked up
//     await _sttService.stopListening();

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));

//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     if (mounted && _isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   Future<void> _playTextToSpeech(String text) async {
//     await _player.stop();
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);
//       await _player.setAudioSource(CustomAudioSource(bytes));

//       _playerSubscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return;

//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             _triggerAction(_stopHearController);
//             _playerSubscription?.cancel();
//             _playerSubscription = null;
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//     } catch (e) {
//       _handleError('Text-to-speech error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   // If user wants to skip TTS mid-sentence
//   void _interruptSpeech() async {
//     await _player.stop();
//     if (!mounted) return;

//     if (_isInSession) {
//       _triggerAction(_hearController);
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   // ------------------ SAVE SESSION (WITH DETECTION DATA) ------------------
//   Future<void> _saveSessionToFirestore() async {
//     try {
//       final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProvider.childId;

//       if (childId == null) {
//         debugPrint('No childId found, cannot save session.');
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();
//       if (!childDoc.exists) {
//         debugPrint('Child doc does not exist, cannot save session.');
//         return;
//       }

//       final therapistId = childDoc.data()?['therapistId'] ?? '';

//       // Build conversation text from chat
//       final conversationText = _chatHistory.map((msg) {
//         final who = msg.isUser ? 'User' : 'AI';
//         return '$who: ${msg.text}';
//       }).join('\n');

//       // Build detection results
//       final detectionData = _prepareDetectionData();

//       // Save to "session" collection
//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'conversation': conversationText,
//         'detectionduringsession': detectionData,
//       });

//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }

//   // Convert counts + changes into a Map
//   Map<String, dynamic> _prepareDetectionData() {
//     // We can also compute percentages:
//     // e.g. if each frame is effectively 5s, or we just keep counts.
//     // If you want a percentage of how often each behavior occurred:
//     //    percentage = (count / _totalFrames) * 100.0
//     final behaviorPercentages = <String, double>{};
//     _behaviorCounts.forEach((behavior, count) {
//       if (_totalFrames > 0) {
//         behaviorPercentages[behavior] = (count / _totalFrames) * 100;
//       } else {
//         behaviorPercentages[behavior] = 0.0;
//       }
//     });

//     final emotionPercentages = <String, double>{};
//     _emotionCounts.forEach((emotion, count) {
//       if (_totalFrames > 0) {
//         emotionPercentages[emotion] = (count / _totalFrames) * 100;
//       } else {
//         emotionPercentages[emotion] = 0.0;
//       }
//     });

//     return {
//       'totalFrames': _totalFrames,
//       'behaviorCounts': _behaviorCounts,
//       'behaviorChanges': _behaviorChanges,
//       'behaviorPercentages': behaviorPercentages,
//       'emotionCounts': _emotionCounts,
//       'emotionChanges': _emotionChanges,
//       'emotionPercentages': emotionPercentages,
//     };
//   }

//   // ------------------ UTILS ------------------
//   void _addMessage(ChatMessage message) {
//     setState(() => _chatHistory.add(message));
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (!mounted) return;
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
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

//   void _handleError(String message) {
//     debugPrint('Error: $message');
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     // Stop detection
//     _stopDetectionLoop();

//     // Dispose camera
//     _cameraController?.dispose();

//     // Cancel TTS subscription
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     // Stop STT
//     _sttService.stopListening();

//     // Dispose audio player
//     _player.dispose();

//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Assistant + Behavior Detection'),
//       ),
//       body: Column(
//         children: [
//           // 1) Camera preview at top
//           if (_cameraController != null && _cameraController!.value.isInitialized)
//             AspectRatio(
//               aspectRatio: _cameraController!.value.aspectRatio,
//               child: CameraPreview(_cameraController!),
//             )
//           else
//             Container(
//               height: 200,
//               color: Colors.black12,
//               child: const Center(child: Text("Camera not available")),
//             ),

//           // 2) RIVE animation
//           Expanded(
//             flex: 3,
//             child: RiveAnimation.asset(
//               'assets/login_screen_character.riv',
//               controllers: [
//                 _talkController,
//                 _hearController,
//                 _stopHearController,
//               ],
//               fit: BoxFit.contain,
//             ),
//           ),

//           // 3) Status text
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

//           // 4) Show partial recognized text
//           if (_currentBuffer.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 'Heard so far: $_currentBuffer',
//                 style: const TextStyle(fontSize: 14.0),
//               ),
//             ),

//           // 5) Chat messages
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

//           // 6) Buttons (Start/End + Interrupt)
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isInSession
//                       ? _endConversationSession
//                       : _startConversationSession,
//                   icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//                   label: Text(_isInSession ? 'End Call' : 'Start Call'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isInSession ? Colors.red : Colors.green,
//                     foregroundColor: Colors.white,
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//                 if (_isInSession)
//                   ElevatedButton.icon(
//                     onPressed: _interruptSpeech,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Interrupt'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 24, vertical: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:rive/rive.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;

// // Local imports:
// import 'package:mind_speak_app/audio/customesource.dart';
// import 'package:mind_speak_app/components/chat_bubble.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsService.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';

// class start_session extends StatefulWidget {
//   const start_session({Key? key}) : super(key: key);

//   @override
//   State<start_session> createState() => _StartSessionState();
// }

// class _StartSessionState extends State<start_session> {
//   // ------------------ CAMERA + DETECTION FIELDS ------------------
//   CameraController? _cameraController;
//   Timer? _detectionTimer;
//   bool _isDetecting = false; // True if detection is running

//   // We'll track how many frames captured for each endpoint
//   int _totalFrames = 0;

//   // Emotion detection
//   final Map<String, int> _emotionCounts = {};
//   String _lastEmotion = '';
//   int _emotionChanges = 0;

//   // Behavior detection
//   final Map<String, int> _behaviorCounts = {};
//   String _lastBehavior = '';
//   int _behaviorChanges = 0;

//   // We'll have two separate endpoints:
//   final String _emotionUrl = 'http://192.168.1.17:5000/emotion-detection';
//   final String _behaviorUrl = 'http://192.168.1.17:5001/analyze_frame';

//   // ------------------ AUDIO / CHAT FIELDS ------------------
//   final _sttService = STTService();
//   final _ttsService = TTSService();
//   final _chatService = ChatService();

//   final AudioPlayer _player = AudioPlayer();
//   StreamSubscription<PlayerState>? _playerSubscription;

//   List<ChatMessage> _chatHistory = [];
//   final ScrollController _scrollController = ScrollController();

//   late OneShotAnimation _talkController;
//   late OneShotAnimation _hearController;
//   late OneShotAnimation _stopHearController;

//   bool _isInSession = false;
//   bool _isProcessingResponse = false;
//   String _currentBuffer = "";

//   @override
//   void initState() {
//     super.initState();
//     // Rive animations
//     _talkController = OneShotAnimation('Talk', autoplay: false);
//     _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
//     _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

//     _initializeApp();     // STT + permissions
//     _initializeCamera();  // Prepare camera for background detection (no preview)
//   }

//   // ------------------ PERMISSIONS, STT INIT ------------------
//   Future<void> _initializeApp() async {
//     try {
//       await _checkPermissions();
//       await _sttService.initialize(
//         onError: (error) {
//           _handleError('Speech error: ${error.errorMsg}');
//           _endConversationSession();
//         },
//         onStatus: (status) {
//           // handle STT status changes if needed
//         },
//       );
//       _validateApiKeys();
//     } catch (e) {
//       _handleError('Initialization error: $e');
//     }
//   }

//   void _validateApiKeys() {
//     final elApiKey = dotenv.env['EL_API_KEY'];
//     final geminiKey = dotenv.env['GEMINI_API_KEY'];

//     if (elApiKey == null || elApiKey.isEmpty) {
//       _handleError('ElevenLabs API key not found in .env file');
//     }
//     if (geminiKey == null || geminiKey.isEmpty) {
//       _handleError('Gemini AI API key not found in .env file');
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final micStatus = await Permission.microphone.request();
//     if (!micStatus.isGranted) {
//       throw Exception('Microphone permission is required.');
//     }
//     final camStatus = await Permission.camera.request();
//     if (!camStatus.isGranted) {
//       throw Exception('Camera permission is required.');
//     }
//   }

//   // ------------------ CAMERA INIT (NO PREVIEW SHOWN) ------------------
//   Future<void> _initializeCamera() async {
//     try {
//       final cameras = await availableCameras();
//       final frontCam = cameras.firstWhere(
//         (cam) => cam.lensDirection == CameraLensDirection.front,
//       );
//       _cameraController = CameraController(
//         frontCam,
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );
//       await _cameraController!.initialize();
//       // We won't display a preview, but the camera is ready for captures
//     } catch (e) {
//       debugPrint('Camera init error: $e');
//     }
//   }

//   // ------------------ START / STOP DETECTION ------------------
//   void _startDetectionLoop() {
//     if (_cameraController == null ||
//         !_cameraController!.value.isInitialized ||
//         _isDetecting) {
//       return;
//     }
//     _isDetecting = true;
//     _totalFrames = 0;

//     // Reset counts
//     _emotionCounts.clear();
//     _emotionChanges = 0;
//     _lastEmotion = '';

//     _behaviorCounts.clear();
//     _behaviorChanges = 0;
//     _lastBehavior = '';

//     // For example, capture frames every 5 seconds
//     _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//       _captureFrame();
//     });
//   }

//   void _stopDetectionLoop() {
//     _detectionTimer?.cancel();
//     _detectionTimer = null;
//     _isDetecting = false;
//   }

//   Future<void> _captureFrame() async {
//     if (!_isDetecting || _cameraController == null) return;
//     try {
//       final XFile file = await _cameraController!.takePicture();
//       final Uint8List imageBytes = await file.readAsBytes();

//       // We'll call 2 separate endpoints: one for emotion, one for behavior
//       _detectEmotion(imageBytes);
//       _detectBehavior(imageBytes);

//       // Count total frames (just once each cycle)
//       _totalFrames++;
//     } catch (e) {
//       debugPrint('Error capturing frame: $e');
//     }
//   }

//   // -- EMOTION DETECTION --
//   Future<void> _detectEmotion(Uint8List imageBytes) async {
//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(_emotionUrl));
//       request.files.add(
//         http.MultipartFile.fromBytes('frame', imageBytes, filename: 'frame.jpg'),
//       );

//       final streamed = await request.send();
//       final resp = await http.Response.fromStream(streamed);
//       if (resp.statusCode == 200) {
//         final data = jsonDecode(resp.body);
//         final emotion = data['emotion'] ?? '';

//         if (!mounted) return;
//         if (emotion.isNotEmpty) {
//           setState(() {
//             _emotionCounts[emotion] = (_emotionCounts[emotion] ?? 0) + 1;
//             if (_lastEmotion.isNotEmpty && _lastEmotion != emotion) {
//               _emotionChanges++;
//             }
//             _lastEmotion = emotion;
//           });
//         }
//       } else {
//         debugPrint('Emotion server error: ${resp.body}');
//       }
//     } catch (e) {
//       debugPrint('detectEmotion error: $e');
//     }
//   }

//   // -- BEHAVIOR DETECTION --
//   Future<void> _detectBehavior(Uint8List imageBytes) async {
//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(_behaviorUrl));
//       request.files.add(
//         http.MultipartFile.fromBytes('frame', imageBytes, filename: 'frame.jpg'),
//       );

//       final streamed = await request.send();
//       final resp = await http.Response.fromStream(streamed);
//       if (resp.statusCode == 200) {
//         final data = jsonDecode(resp.body);
//         final behavior = data['behavior'] ?? '';

//         if (!mounted) return;
//         if (behavior.isNotEmpty) {
//           setState(() {
//             _behaviorCounts[behavior] = (_behaviorCounts[behavior] ?? 0) + 1;
//             if (_lastBehavior.isNotEmpty && _lastBehavior != behavior) {
//               _behaviorChanges++;
//             }
//             _lastBehavior = behavior;
//           });
//         }
//       } else {
//         debugPrint('Behavior server error: ${resp.body}');
//       }
//     } catch (e) {
//       debugPrint('detectBehavior error: $e');
//     }
//   }

//   // ------------------ WELCOME MESSAGE FROM CHILD DATA ------------------
//   Future<void> _autoWelcomeChild() async {
//     try {
//       final sessionProv = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProv.childId;
//       if (childId == null) {
//         // If no child, just say generic welcome
//         await _processWithLLM("Hello there! How can I help you today?");
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         // If child doc not found, fallback
//         await _processWithLLM("Hello there! How can I help you today?");
//         return;
//       }

//       final data = childDoc.data()!;
//       final childName = data['name'] ?? 'friend';

//       final welcomePrompt =
//           "Hello $childName! I'm here to chat with you. "
//           "What are some of your favorite things to do or learn about?";

//       // This calls LLM -> TTS -> etc.
//       await _processWithLLM(welcomePrompt);
//     } catch (e) {
//       debugPrint("Error in _autoWelcomeChild: $e");
//       await _processWithLLM("Hello! I'm here to help you today.");
//     }
//   }

//   // ------------------ START / END SESSION ------------------
//   void _startConversationSession() async {
//     if (_isInSession) return;

//     setState(() => _isInSession = true);

//     // 1) Send welcome message (child name from DB)
//     await _autoWelcomeChild();
//     if (!mounted) return;

//     // 2) Start detection loop
//     _startDetectionLoop();

//     // 3) Start STT
//     _triggerAction(_hearController);
//     _startContinuousListening();
//   }

//   Future<void> _endConversationSession() async {
//     // 1) Stop detection
//     _stopDetectionLoop();

//     // 2) Save session
//     await _saveSessionToFirestore();

//     // 3) Stop STT
//     await _sttService.stopListening();

//     if (!mounted) return;
//     setState(() {
//       _isInSession = false;
//       _currentBuffer = "";
//       _isProcessingResponse = false;
//     });

//     _triggerAction(_stopHearController);
//   }

//   // ------------------ STT LOOP ------------------
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

//   // ------------------ LLM + TTS ------------------
//   Future<void> _processWithLLM(String text) async {
//     // Stop STT so TTS doesn't echo
//     await _sttService.stopListening();

//     try {
//       final response = await _chatService.sendMessageToLLM(text);
//       _addMessage(ChatMessage(text: response, isUser: false));

//       // TTS
//       await _playTextToSpeech(response);
//     } catch (e) {
//       _handleError('LLM processing error: $e');
//     }

//     if (mounted && _isInSession) {
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   Future<void> _playTextToSpeech(String text) async {
//     await _player.stop();
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     try {
//       final bytes = await _ttsService.synthesizeSpeech(text);
//       await _player.setAudioSource(CustomAudioSource(bytes));

//       _playerSubscription = _player.playerStateStream.listen((playerState) {
//         if (!mounted) return;

//         switch (playerState.processingState) {
//           case ProcessingState.ready:
//             _triggerAction(_talkController);
//             break;
//           case ProcessingState.completed:
//             _triggerAction(_stopHearController);
//             _playerSubscription?.cancel();
//             _playerSubscription = null;
//             break;
//           default:
//             break;
//         }
//       });

//       await _player.play();
//     } catch (e) {
//       _handleError('TTS error: $e');
//       _triggerAction(_stopHearController);
//     }
//   }

//   // If user wants to skip TTS mid-response
//   void _interruptSpeech() async {
//     await _player.stop();
//     if (!mounted) return;

//     if (_isInSession) {
//       _triggerAction(_hearController);
//       setState(() => _isProcessingResponse = false);
//       _startContinuousListening();
//     }
//   }

//   // ------------------ SAVE SESSION + DETECTION ------------------
//   Future<void> _saveSessionToFirestore() async {
//     try {
//       final sessionProv = Provider.of<SessionProvider>(context, listen: false);
//       final childId = sessionProv.childId;
//       if (childId == null) {
//         debugPrint('No childId found; skipping save.');
//         return;
//       }

//       final childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();
//       if (!childDoc.exists) {
//         debugPrint('Child doc not found; skipping save.');
//         return;
//       }

//       final therapistId = childDoc.data()?['therapistId'] ?? '';

//       final conversationText = _chatHistory.map((msg) {
//         final who = msg.isUser ? 'User' : 'AI';
//         return '$who: ${msg.text}';
//       }).join('\n');

//       final detectionData = _buildDetectionData();

//       await FirebaseFirestore.instance.collection('session').add({
//         'childId': childId,
//         'therapistId': therapistId,
//         'date': DateTime.now().toIso8601String(),
//         'conversation': conversationText,
//         'detectionduringsession': detectionData,
//       });

//       debugPrint('Session saved successfully to Firestore.');
//     } catch (e) {
//       debugPrint('Error saving session: $e');
//     }
//   }

//   Map<String, dynamic> _buildDetectionData() {
//     // Compute emotion percentages
//     final emotionPercentages = <String, double>{};
//     _emotionCounts.forEach((key, count) {
//       if (_totalFrames > 0) {
//         emotionPercentages[key] = (count / _totalFrames) * 100;
//       } else {
//         emotionPercentages[key] = 0;
//       }
//     });

//     // Compute behavior percentages
//     final behaviorPercentages = <String, double>{};
//     _behaviorCounts.forEach((key, count) {
//       if (_totalFrames > 0) {
//         behaviorPercentages[key] = (count / _totalFrames) * 100;
//       } else {
//         behaviorPercentages[key] = 0;
//       }
//     });

//     return {
//       'totalFrames': _totalFrames,

//       'emotionCounts': _emotionCounts,
//       'emotionChanges': _emotionChanges,
//       'emotionPercentages': emotionPercentages,

//       'behaviorCounts': _behaviorCounts,
//       'behaviorChanges': _behaviorChanges,
//       'behaviorPercentages': behaviorPercentages,
//     };
//   }

//   // ------------------ UTILS ------------------
//   void _addMessage(ChatMessage message) {
//     if (!mounted) return;
//     setState(() => _chatHistory.add(message));
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (!mounted) return;
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
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

//   void _handleError(String message) {
//     debugPrint('Error: $message');
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }

//   @override
//   void dispose() {
//     // Stop detection if running
//     _stopDetectionLoop();
//     _cameraController?.dispose();

//     // Cancel TTS subscription
//     _playerSubscription?.cancel();
//     _playerSubscription = null;

//     // Stop STT
//     _sttService.stopListening();
//     _player.dispose();

//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // No camera preview is displayed; detection is background only.
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Assistant + Dual Detection'),
//       ),
//       body: Column(
//         children: [
//           // 1) Rive animations
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

//           // 2) Status text
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

//           // 3) Show partial recognized text
//           if (_currentBuffer.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 'Heard so far: $_currentBuffer',
//                 style: const TextStyle(fontSize: 14.0),
//               ),
//             ),

//           // 4) Chat messages
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

//           // 5) Start/End + Interrupt buttons
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isInSession
//                       ? _endConversationSession
//                       : _startConversationSession,
//                   icon: Icon(_isInSession ? Icons.call_end : Icons.call),
//                   label: Text(_isInSession ? 'End Call' : 'Start Call'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isInSession ? Colors.red : Colors.green,
//                     foregroundColor: Colors.white,
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//                 if (_isInSession)
//                   ElevatedButton.icon(
//                     onPressed: _interruptSpeech,
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Interrupt'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 24, vertical: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

// Local imports:
import 'package:mind_speak_app/audio/customesource.dart';
import 'package:mind_speak_app/components/chat_bubble.dart';
import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart'; // LLM
import 'package:mind_speak_app/service/speechservice.dart'; // STT
import 'package:mind_speak_app/service/ttsService.dart'; // TTS
import 'package:mind_speak_app/providers/session_provider.dart';

class start_session extends StatefulWidget {
  const start_session({Key? key}) : super(key: key);

  @override
  State<start_session> createState() => _StartSessionState();
}

class _StartSessionState extends State<start_session> {
  // ------------------ CAMERA + DETECTION FIELDS ------------------
  CameraController? _cameraController;
  Timer? _detectionTimer;
  bool _isDetecting = false;

  int _totalFrames = 0;

  // For emotion detection
  final Map<String, int> _emotionCounts = {};
  String _lastEmotion = '';
  int _emotionChanges = 0;

  // For behavior detection
  final Map<String, int> _behaviorCounts = {};
  String _lastBehavior = '';
  int _behaviorChanges = 0;

  // Two endpoints
  final String _emotionUrl = 'http://192.168.1.17:5000/emotion-detection';
  final String _behaviorUrl = 'http://192.168.1.17:5001/analyze';

  // ------------------ AUDIO / CHAT FIELDS ------------------
  final _sttService = STTService();
  final _ttsService = TTSService();
  final _chatService =
      ChatService(); // We'll modify it to use short system prompt

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSubscription;

  List<ChatMessage> _chatHistory = [];
  final ScrollController _scrollController = ScrollController();

  late OneShotAnimation _talkController;
  late OneShotAnimation _hearController;
  late OneShotAnimation _stopHearController;

  bool _isInSession = false;
  bool _isProcessingResponse = false;
  String _currentBuffer = "";

  // For the child's name and session count
  String _childName = "friend";
  int _sessionCount = 0; // We will load/increment from child doc

  @override
  void initState() {
    super.initState();
    _talkController = OneShotAnimation('Talk', autoplay: false);
    _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
    _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

    _initializeApp(); // STT + permission
    _initializeCamera(); // Prepare camera (no preview)
  }

  // ------------------ PERMISSIONS, STT INIT ------------------
Future<void> _initializeApp() async {
  try {
    await _checkPermissions();
    // Wait for STT initialization to complete
    final initialized = await _sttService.initialize(
      onError: (error) {
        _handleError('Speech error: ${error.errorMsg}');
        _endConversationSession();
      },
      onStatus: (status) {
        // handle STT status if needed
      },
    );
    
    if (!initialized) {
      throw Exception('Failed to initialize speech recognition');
    }
    
    _validateApiKeys();
  } catch (e) {
    _handleError('Initialization error: $e');
  }
}
  void _validateApiKeys() {
    final elApiKey = dotenv.env['EL_API_KEY'];
    final geminiKey = dotenv.env['GEMINI_API_KEY'];

    if (elApiKey == null || elApiKey.isEmpty) {
      _handleError('ElevenLabs API key not found in .env file');
    }
    if (geminiKey == null || geminiKey.isEmpty) {
      _handleError('Gemini AI API key not found in .env file');
    }
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission is required.');
    }
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      throw Exception('Camera permission is required.');
    }
  }

  // ------------------ CAMERA INIT (NO PREVIEW) ------------------
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ------------------ START / STOP DETECTION ------------------
  void _startDetectionLoop() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('Camera not ready; skipping detection.');
      return;
    }
    if (_isDetecting) return;

    _isDetecting = true;
    _totalFrames = 0;

    // Clear old stats
    _emotionCounts.clear();
    _emotionChanges = 0;
    _lastEmotion = '';
    _behaviorCounts.clear();
    _behaviorChanges = 0;
    _lastBehavior = '';

    // Capture every 5s
    _detectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _captureFrame();
    });
  }

  void _stopDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _isDetecting = false;
  }

  Future<void> _captureFrame() async {
    if (!_isDetecting || _cameraController == null) return;
    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();

      // Do emotion + behavior detection
      _detectEmotion(bytes);
      _detectBehavior(bytes);

      _totalFrames++;
    } catch (e) {
      debugPrint('captureFrame error: $e');
    }
  }

  // -- EMOTION
  Future<void> _detectEmotion(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_emotionUrl));
      request.files.add(
        http.MultipartFile.fromBytes('frame', imageBytes,
            filename: 'frame.jpg'),
      );
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final emo = data['emotion'] ?? '';
        if (!mounted) return;
        if (emo.isNotEmpty) {
          setState(() {
            _emotionCounts[emo] = (_emotionCounts[emo] ?? 0) + 1;
            if (_lastEmotion.isNotEmpty && _lastEmotion != emo) {
              _emotionChanges++;
            }
            _lastEmotion = emo;
          });
        }
      } else {
        debugPrint('Emotion server error: ${resp.body}');
      }
    } catch (e) {
      debugPrint('detectEmotion error: $e');
    }
  }

  // -- BEHAVIOR
  Future<void> _detectBehavior(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_behaviorUrl));
      request.files.add(
        http.MultipartFile.fromBytes('frame', imageBytes,
            filename: 'frame.jpg'),
      );
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final beh = data['behavior'] ?? '';
        if (!mounted) return;
        if (beh.isNotEmpty) {
          setState(() {
            _behaviorCounts[beh] = (_behaviorCounts[beh] ?? 0) + 1;
            if (_lastBehavior.isNotEmpty && _lastBehavior != beh) {
              _behaviorChanges++;
            }
            _lastBehavior = beh;
          });
        }
      } else {
        debugPrint('Behavior server error: ${resp.body}');
      }
    } catch (e) {
      debugPrint('detectBehavior error: $e');
    }
  }

  // ------------------ WELCOME MESSAGE + CHILD DATA + SESSION COUNT ------------------
  Future<void> _fetchChildInfoAndIncrementSession() async {
    try {
      final sessProv = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessProv.childId;
      if (childId == null) {
        // no child doc
        _childName = "friend";
        _sessionCount = 1;
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();

      if (!doc.exists) {
        _childName = "friend";
        _sessionCount = 1;
        return;
      }

      final data = doc.data()!;
      _childName = data['name'] ?? 'friend';

      // get sessionCount from doc. If not found, default 0
      final currentCount = data['sessionCount'] ?? 0;
      _sessionCount = currentCount + 1;

      // update child doc with new count
      await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .update({'sessionCount': _sessionCount});
    } catch (e) {
      debugPrint('Error fetching/incrementing sessionCount: $e');
      _childName = "friend";
      _sessionCount = 1;
    }
  }

  Future<void> _sayWelcomeMessage() async {
    // Provide short answers system prompt
    final prompt = "Hello $_childName! I'm here to chat with you. "
        "Please talk about anything you like. Keep answers short, no special chars.";
    await _processWithLLM(prompt);
  }

  // ------------------ START / END SESSION ------------------
  void _startConversationSession() async {
    if (_isInSession) return;

    setState(() => _isInSession = true);

    // 1) fetch child info + increment session count
    await _fetchChildInfoAndIncrementSession();
    if (!mounted) return;

    // 2) say welcome
    await _sayWelcomeMessage();
    if (!mounted) return;

    // 3) start detection
    _startDetectionLoop();

    // 4) start STT
    _triggerAction(_hearController);
    _startContinuousListening();
  }

  Future<void> _endConversationSession() async {
    // 1) stop detection
    _stopDetectionLoop();

    // 2) save session
    await _saveSessionToFirestore();

    // 3) generate final therapist report
    await _generateReport();

    // 4) stop STT
    await _sttService.stopListening();

    if (!mounted) return;
    setState(() {
      _isInSession = false;
      _currentBuffer = "";
      _isProcessingResponse = false;
    });

    _triggerAction(_stopHearController);
  }

  // ------------------ STT LOOP ------------------
Future<void> _startContinuousListening() async {
  if (!_isInSession) return;
  
  // Double check initialization
  if (!_sttService.isInitialized) {
    await _sttService.initialize(
      onError: (error) {
        _handleError('Speech error: ${error.errorMsg}');
        _endConversationSession();
      },
      onStatus: (status) {},
    );
  }
  
  try {
    await _sttService.startListening(
      onResult: (words, confidence, isFinal) {
        if (!mounted || !_isInSession) return;
        setState(() => _currentBuffer = words);

        if (isFinal && words.isNotEmpty) {
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
    final text = _currentBuffer.trim();
    if (text.isEmpty || _isProcessingResponse) return;

    setState(() {
      _currentBuffer = "";
      _isProcessingResponse = true;
    });

    _addMessage(ChatMessage(text: text, isUser: true));
    await _processWithLLM(text);
  }

  // ------------------ LLM + TTS ------------------
  Future<void> _processWithLLM(String userText) async {
    // 1) Stop STT so TTS won't echo
    await _sttService.stopListening();

    try {
      // We pass user text to LLM with a short system prompt to ensure short answers
      final response = await _chatService.sendMessageToLLM(
        userText,
        systemPrompt:
            "You are a helpful assistant. Keep your answers short, no special chars. "
            "Respond quickly with minimal text.",
        maxTokens: 60, // shorten for performance
        temperature: 0.3, // keep it less creative
      );
      _addMessage(ChatMessage(text: response, isUser: false));

      // 2) TTS
      await _playTextToSpeech(response);
    } catch (e) {
      _handleError('LLM processing error: $e');
    }

    if (mounted && _isInSession) {
      setState(() => _isProcessingResponse = false);
      _startContinuousListening();
    }
  }

  Future<void> _playTextToSpeech(String text) async {
    await _player.stop();
    _playerSubscription?.cancel();
    _playerSubscription = null;

    try {
      final bytes = await _ttsService.synthesizeSpeech(text);
      await _player.setAudioSource(CustomAudioSource(bytes));

      _playerSubscription = _player.playerStateStream.listen((playerState) {
        if (!mounted) return;

        switch (playerState.processingState) {
          case ProcessingState.ready:
            _triggerAction(_talkController);
            break;
          case ProcessingState.completed:
            _triggerAction(_stopHearController);
            _playerSubscription?.cancel();
            _playerSubscription = null;
            break;
          default:
            break;
        }
      });

      await _player.play();
    } catch (e) {
      _handleError('TTS error: $e');
      _triggerAction(_stopHearController);
    }
  }

  void _interruptSpeech() async {
    await _player.stop();
    if (!mounted) return;
    if (_isInSession) {
      _triggerAction(_hearController);
      setState(() => _isProcessingResponse = false);
      _startContinuousListening();
    }
  }

  // ------------------ SAVE SESSION + DETECTION ------------------
  Future<void> _saveSessionToFirestore() async {
    try {
      final sessProv = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessProv.childId;
      if (childId == null) {
        debugPrint('No childId found; skipping saving session.');
        return;
      }

      final childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();
      if (!childDoc.exists) {
        debugPrint('Child doc not found; skipping saving session.');
        return;
      }

      final therapistId = childDoc.data()?['therapistId'] ?? '';

      final conversationText = _chatHistory.map((msg) {
        final who = msg.isUser ? 'User' : 'AI';
        return '$who: ${msg.text}';
      }).join('\n');

      final detectionData = _buildDetectionData();

      // Save the session doc
      await FirebaseFirestore.instance.collection('session').add({
        'childId': childId,
        'therapistId': therapistId,
        'sessionNumforChild': _sessionCount, // store the incremented session
        'date': DateTime.now().toIso8601String(),
        'conversation': conversationText,
        'detectionduringsession': detectionData,
      });

      debugPrint('Session saved successfully.');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Map<String, dynamic> _buildDetectionData() {
    // Compute emotion & behavior percentages
    final emotionPercentages = <String, double>{};
    _emotionCounts.forEach((emo, count) {
      if (_totalFrames > 0) {
        emotionPercentages[emo] = (count / _totalFrames) * 100.0;
      } else {
        emotionPercentages[emo] = 0.0;
      }
    });
    final behaviorPercentages = <String, double>{};
    _behaviorCounts.forEach((beh, count) {
      if (_totalFrames > 0) {
        behaviorPercentages[beh] = (count / _totalFrames) * 100.0;
      } else {
        behaviorPercentages[beh] = 0.0;
      }
    });

    return {
      'totalFrames': _totalFrames,
      'emotionCounts': _emotionCounts,
      'emotionChanges': _emotionChanges,
      'emotionPercentages': emotionPercentages,
      'behaviorCounts': _behaviorCounts,
      'behaviorChanges': _behaviorChanges,
      'behaviorPercentages': behaviorPercentages,
    };
  }

  // ------------------ GENERATE REPORT FOR THERAPIST ------------------
  Future<void> _generateReport() async {
    // We gather the conversation + detection data, pass them to LLM,
    // then store in "reports" collection.
    try {
      final sessProv = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessProv.childId;
      if (childId == null) {
        debugPrint('No childId for report generation.');
        return;
      }

      final conversationText = _chatHistory.map((msg) {
        final who = msg.isUser ? 'User' : 'AI';
        return '$who: ${msg.text}';
      }).join('\n');
      final detectionData = _buildDetectionData(); // same method

      // Let's create a summary prompt
      final summaryPrompt = """
Given the conversation below and the detection results, produce a short analysis of the child's state and a brief recommendation for the therapist. No special characters, keep it short.

Conversation:
$conversationText

Detection:
$detectionData

Please respond in JSON with fields: "analysis", "progress", and "recommendation".
""";

      // We use ChatService again with short answers
      final llmResponse = await _chatService.sendMessageToLLM(
        summaryPrompt,
        systemPrompt:
            "You are a helpful tool generating short, simple JSON reports. No special chars. Keep it short.",
        maxTokens: 100,
        temperature: 0.2,
      );

      // Attempt to parse JSON
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(llmResponse);
      } catch (_) {
        // fallback if the LLM didn't strictly produce JSON
        parsed = {
          "analysis": "Could not parse analysis",
          "progress": "",
          "recommendation": ""
        };
      }

      final analysis = parsed["analysis"] ?? "";
      final progress = parsed["progress"] ?? "";
      final recommendation = parsed["recommendation"] ?? "";

      // Save to "reports"
      await FirebaseFirestore.instance.collection('reports').add({
        'childId': childId,
        'sessionId': 'TODO-FIND-SESSION-ID', // or pass actual session doc id
        'analysis': analysis,
        'progress': progress,
        'recommendation': recommendation,
      });

      debugPrint("Report generated and saved to 'reports'.");
    } catch (e) {
      debugPrint('Error generating final report: $e');
    }
  }

  // ------------------ UTILS ------------------
  void _addMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() => _chatHistory.add(message));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  void _handleError(String message) {
    debugPrint('Error: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    // stop detection
    _stopDetectionLoop();
    _cameraController?.dispose();

    // cancel TTS subscription
    _playerSubscription?.cancel();
    _playerSubscription = null;

    // stop STT
    _sttService.stopListening();
    _player.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No camera preview shown, detection is hidden
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Assistant + Child Report'),
      ),
      body: Column(
        children: [
          // Rive animations
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

          // Status text
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

          // partial STT text
          if (_currentBuffer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Heard so far: $_currentBuffer',
                style: const TextStyle(fontSize: 14.0),
              ),
            ),

          // chat messages
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

          // Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInSession
                      ? _endConversationSession
                      : _startConversationSession,
                  icon: Icon(_isInSession ? Icons.call_end : Icons.call),
                  label: Text(_isInSession ? 'End Call' : 'Start Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isInSession ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                if (_isInSession)
                  ElevatedButton.icon(
                    onPressed: _interruptSpeech,
                    icon: const Icon(Icons.stop),
                    label: const Text('Interrupt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
