// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mind_speak_app/models/message.dart';
// import 'package:mind_speak_app/service/llmservice.dart';
// import 'package:mind_speak_app/service/speechservice.dart';
// import 'package:mind_speak_app/service/ttsservice.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// class ChatProvider extends ChangeNotifier {
//   late final SpeechService speechService;
//   late final TTSService ttsService;
//   late final LLMService llmService;

//   bool isInSession = false;
//   bool isSpeaking = false;
//   bool isListening = false;
//   bool isProcessingResponse = false;
//   String currentBuffer = '';
//   List<ChatMessage> chatHistory = [];

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

//     await speechService.initialize(
//       onError: (error) => print('Speech error: ${error.errorMsg}'),
//       onStatus: (status) {
//         print('Speech status: $status');
//         if (status == 'done') {
//           isListening = false;
//           notifyListeners();
//         }
//       },
//     );

//     // Listen to TTS speaking state
//     ttsService.isSpeakingStream.listen((speaking) {
//       isSpeaking = speaking;
//       notifyListeners();
      
//       // If we finished speaking and still in session, start listening again
//       if (!speaking && isInSession && !isProcessingResponse) {
//         Future.delayed(const Duration(milliseconds: 500), () {
//           _startListening();
//         });
//       }
//     });
//   }

//   Future<void> startSession() async {
//     if (isInSession) return;

//     isInSession = true;
//     isProcessingResponse = false;
//     isSpeaking = false;
//     currentBuffer = '';
//     notifyListeners();

//     await _startListening();
//   }

//   Future<void> _startListening() async {
//     if (!isInSession || isSpeaking || isProcessingResponse) return;

//     try {
//       isListening = true;
//       notifyListeners();

//       await speechService.startListening(
//         onResult: (result) async {
//           if (!isInSession) return; // Check if still in session

//           if (result.finalResult && result.recognizedWords.isNotEmpty) {
//             isListening = false;
//             isProcessingResponse = true;
//             notifyListeners();

//             try {
//               // Add user message to chat
//               chatHistory.add(ChatMessage(
//                 text: result.recognizedWords,
//                 isUser: true,
//               ));
//               notifyListeners();

//               // Get and process AI response
//               final response = await llmService.getResponse(result.recognizedWords);
//               chatHistory.add(ChatMessage(
//                 text: response,
//                 isUser: false,
//               ));
//               notifyListeners();

//               // Speak the response
//               await ttsService.speak(response);
//             } catch (e) {
//               print('Error processing response: $e');
//               isProcessingResponse = false;
//               if (isInSession) _startListening(); // Retry listening if still in session
//             }
//           } else {
//             // Update current buffer for partial results
//             currentBuffer = result.recognizedWords;
//             notifyListeners();
//           }
//         },
//         listenFor: const Duration(seconds: 30),
//         pauseFor: const Duration(seconds: 3),
//       );
//     } catch (e) {
//       print('Error starting listening: $e');
//       isListening = false;
//       if (isInSession) {
//         Future.delayed(const Duration(seconds: 1), _startListening);
//       }
//       notifyListeners();
//     }
//   }

//   Future<void> endSession() async {
//     isInSession = false;
//     await speechService.stop();
//     await ttsService.stop();
//     isProcessingResponse = false;
//     isSpeaking = false;
//     isListening = false;
//     currentBuffer = '';
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     ttsService.dispose();
//     super.dispose();
//   }
// }