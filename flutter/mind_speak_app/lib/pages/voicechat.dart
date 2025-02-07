// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';

// class ChatMessage {
//   final String text;
//   final bool isUser;
//   ChatMessage(this.text, this.isUser);
// }

// class VoiceChatPage extends StatefulWidget {
//   const VoiceChatPage({Key? key}) : super(key: key);

//   @override
//   State<VoiceChatPage> createState() => _VoiceChatPageState();
// }

// class _VoiceChatPageState extends State<VoiceChatPage> {
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   final FlutterTts _flutterTts = FlutterTts();
//   final List<ChatMessage> _messages = [];
//   bool _isListening = false;
//   bool _isSpeaking = false;
//   late GenerativeModel _model;
//   late ChatSession _chat;

//   @override
//   void initState() {
//     super.initState();
//     _initSpeech();
//     _initTts();
//     _initGemini();
//   }

//   void _initSpeech() async {
//     await _speech.initialize(
//       onStatus: (status) => print('STT Status: $status'),
//       onError: (error) => print('STT Error: $error'),
//     );
//   }

//   void _initTts() async {
//     await _flutterTts.setLanguage("en-US");
//     await _flutterTts.setPitch(1.0);
//     await _flutterTts.setSpeechRate(0.9);

//     _flutterTts.setCompletionHandler(() {
//       setState(() {
//         _isSpeaking = false;
//       });
//     });
//   }

//   void _initGemini() {
//     final apiKey = dotenv.env['GEMINI_API_KEY']!;
//     final model = GenerativeModel(
//       model: 'gemini-pro',
//       apiKey: apiKey,
//     );
//     _model = model;
//     _chat = _model.startChat();
//   }

//   Future<void> _listen() async {
//     if (!_isListening) {
//       if (await _speech.initialize()) {
//         setState(() => _isListening = true);
//         _speech.listen(
//           onResult: (result) {
//             if (result.finalResult) {
//               setState(() => _isListening = false);
//               _processUserInput(result.recognizedWords);
//             }
//           },
//         );
//       }
//     } else {
//       setState(() => _isListening = false);
//       _speech.stop();
//     }
//   }

//   Future<void> _processUserInput(String text) async {
//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add(ChatMessage(text, true));
//     });

//     try {
//       final response = await _chat.sendMessage(Content.text(text));
//       final aiResponse = response.text ?? "Sorry, I couldn't generate a response";

//       setState(() {
//         _messages.add(ChatMessage(aiResponse, false));
//       });

//       await _speak(aiResponse);
//     } catch (e) {
//       print('Error getting AI response: $e');
//       const errorMsg = "Sorry, I encountered an error processing your request.";
//       setState(() {
//         _messages.add(ChatMessage(errorMsg, false));
//       });
//       await _speak(errorMsg);
//     }
//   }

//   Future<void> _speak(String text) async {
//     if (!_isSpeaking) {
//       setState(() => _isSpeaking = true);
//       await _flutterTts.speak(text);
//     }
//   }

//   @override
//   void dispose() {
//     _speech.stop();
//     _flutterTts.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI Voice Chat'),
//         actions: [
//           if (_isSpeaking)
//             IconButton(
//               icon: const Icon(Icons.stop),
//               onPressed: () {
//                 _flutterTts.stop();
//                 setState(() => _isSpeaking = false);
//               },
//             ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16.0),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4.0),
//                   child: Align(
//                     alignment: message.isUser
//                       ? Alignment.centerRight
//                       : Alignment.centerLeft,
//                     child: Container(
//                       padding: const EdgeInsets.all(12.0),
//                       decoration: BoxDecoration(
//                         color: message.isUser
//                           ? Colors.blue[100]
//                           : Colors.grey[300],
//                         borderRadius: BorderRadius.circular(15.0),
//                       ),
//                       constraints: BoxConstraints(
//                         maxWidth: MediaQuery.of(context).size.width * 0.7,
//                       ),
//                       child: Text(
//                         message.text,
//                         style: const TextStyle(fontSize: 16.0),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 FloatingActionButton(
//                   onPressed: _listen,
//                   child: Icon(_isListening ? Icons.mic : Icons.mic_none),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
// }
import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/sessionservice.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceChatPage extends StatefulWidget {
  const VoiceChatPage({super.key});

  @override
  State<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage> {
  final _log = Logger('VoiceChatPage');
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isSpeaking = false;
  late GenerativeModel _model;
  late ChatSession _chat;

  // Rive controllers
  OneShotAnimation _talkController = OneShotAnimation('Talk', autoplay: false);
  OneShotAnimation _hearController =
      OneShotAnimation('hands_hear_start', autoplay: false);
  OneShotAnimation _stophearController =
      OneShotAnimation('hands_hear_stop', autoplay: false);
  OneShotAnimation _successController =
      OneShotAnimation('success', autoplay: false);
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _initSpeech();
    await _initTts();
    _initGemini();
    if (mounted) {
      await _initSession();
    }
  }

  Future<void> _initSession() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final sessionManager =
        Provider.of<SessionManagerProvider>(context, listen: false);

    if (sessionProvider.childId != null && sessionProvider.userId != null) {
      await sessionManager.initializeSession(
        childId: sessionProvider.childId!,
        therapistId: sessionProvider.userId!,
      );
    }
  }

  void _initRiveControllers() {
    _talkController = OneShotAnimation('Talk', autoplay: false);
    _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
    _stophearController = OneShotAnimation('hands_hear_stop', autoplay: false);
    _successController = OneShotAnimation('success', autoplay: false);
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        _log.info('STT Status: $status');
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() => _isListening = false);
            _triggerAnimation(_stophearController);
          }
        }
      },
      onError: (error) {
        _log.warning('STT Error: $error');
        if (mounted) {
          setState(() => _isListening = false);
          _triggerAnimation(_stophearController);
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.9);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _triggerAnimation(_successController);
      }
    });
  }

  void _initGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    _chat = _model.startChat();
  }

  void _triggerAnimation(OneShotAnimation controller) {
    if (!mounted) return;
    setState(() {
      _talkController.isActive = false;
      _hearController.isActive = false;
      _successController.isActive = false;
      _stophearController.isActive = false;
      controller.isActive = true;
    });
  }

  Future<void> _toggleListening() async {
    try {
      if (!_isListening) {
        var available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _triggerAnimation(_hearController);

          await _speech.listen(
            onResult: (result) {
              if (result.finalResult) {
                _processUserInput(result.recognizedWords);
              }
            },
            listenMode: ListenMode.dictation,
            partialResults: true,
            listenFor: const Duration(seconds: 60),
            pauseFor: const Duration(seconds: 3),
            cancelOnError: false,
          );
        }
      } else {
        setState(() => _isListening = false);
        await _speech.stop();
        _triggerAnimation(_stophearController);
      }
    } catch (e) {
      _log.severe('Error in _toggleListening: $e');
      if (mounted) {
        setState(() => _isListening = false);
        _triggerAnimation(_stophearController);
      }
    }
  }

  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    // Add user message
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: true));
      });
    }

    // Save user message
    if (mounted) {
      await Provider.of<SessionManagerProvider>(context, listen: false)
          .saveMessage(text, true);
    }

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final aiResponse =
          response.text ?? "Sorry, I couldn't generate a response";

      if (mounted) {
        // Add AI response
        setState(() {
          _messages.add(ChatMessage(text: aiResponse, isUser: false));
        });

        // Save AI response
        await Provider.of<SessionManagerProvider>(context, listen: false)
            .saveMessage(aiResponse, false);

        await _speak(aiResponse);
      }
    } catch (e) {
      _log.severe('Error getting AI response: $e');
      const errorMsg = "Sorry, I encountered an error processing your request.";
      if (mounted) {
        setState(() {
          _messages.add(const ChatMessage(text: errorMsg, isUser: false));
        });
        await _speak(errorMsg);
      }
    }
  }

  Future<void> _speak(String text) async {
    if (!_isSpeaking && mounted) {
      setState(() => _isSpeaking = true);
      _triggerAnimation(_talkController);
      await _flutterTts.speak(text);
    }
  }

  Future<void> _endSession() async {
    final sessionManager =
        Provider.of<SessionManagerProvider>(context, listen: false);
    await sessionManager.endCurrentSession();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Chat'),
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                _flutterTts.stop();
                setState(() => _isSpeaking = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _endSession,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: RiveAnimation.asset(
              'assets/login_screen_character.riv',
              controllers: [
                _talkController,
                _hearController,
                _successController,
                _stophearController,
              ],
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? Colors.blue[100]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: !_isSpeaking ? _toggleListening : null,
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
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

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({
    required this.text,
    required this.isUser,
  });
}
