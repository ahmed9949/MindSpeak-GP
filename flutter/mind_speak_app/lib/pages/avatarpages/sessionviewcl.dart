// lib/views/session/session_view.dart
import 'package:flutter/material.dart';
import 'package:mind_speak_app/models/session_statistics.dart';
import 'package:mind_speak_app/models/sessionstate.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:mind_speak_app/service/avatarservice/conversationsetup.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class SessionView extends StatefulWidget {
  final String initialPrompt;
  final String initialResponse;
  final Map<String, dynamic> childData;

  const SessionView({
    super.key,
    required this.initialPrompt,
    required this.initialResponse,
    required this.childData,
  });

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final Flutter3DController controller = Flutter3DController();
  bool isModelLoaded = false;
  bool isLoading = true;
  String? errorMessage; 
  final List<String> allowedAnimations = ['idle.001', 'newtalk'];

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final ChatGptTtsService _ttsService = ChatGptTtsService();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _callStarted = false;
  String? _childName;
  final Map<String, dynamic> _detectionStats = {};
  late ChatGptModel _chatModel;

  @override
  void initState() {
    super.initState();
    _childName = widget.childData['name'];
    _chatModel = ConversationModule.createGenerativeModel();
    _initSpeech();
    // _initTts();
    controller.onModelLoaded.addListener(_onModelLoaded);
    _callStarted = true;
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() => _isListening = false);
            _playAnimation(allowedAnimations[0]);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _playAnimation(allowedAnimations[0]);
        }
      },
    );
  }

  // Future<void> _initTts() async {
  //   await _flutterTts.setLanguage("ar-EG");
  //   await _flutterTts.setPitch(1.0);
  //   await _flutterTts.setSpeechRate(0.5);
  //   _flutterTts.setCompletionHandler(() {
  //     if (mounted) {
  //       setState(() => _isSpeaking = false);
  //       _playAnimation(allowedAnimations[0]);
  //     }
  //   });
  // }

  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      setState(() {
        isModelLoaded = true;
        isLoading = false;
      });
      _playAnimation(allowedAnimations[0]);
      if (widget.initialResponse.isNotEmpty) {
        _speak(widget.initialResponse);
      }
    }
  }

  void _playAnimation(String animationName) {
    try {
      controller.playAnimation(animationName: animationName);
      if (animationName == allowedAnimations[1]) {
      } else {
        controller.resetCameraTarget();
        controller.resetCameraOrbit();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Animation error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleListening() async {
    try {
      if (!_isListening) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _playAnimation(allowedAnimations[0]);
          await _speech.listen(
            onResult: (result) {
              if (result.finalResult) {
                _processUserInput(result.recognizedWords);
              }
            },
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            listenFor: const Duration(seconds: 60),
            pauseFor: const Duration(seconds: 3),
            cancelOnError: false,
            localeId: 'ar-EG',
          );
        }
      } else {
        setState(() => _isListening = false);
        await _speech.stop();
        _playAnimation(allowedAnimations[0]);
      }
    } catch (e) {
      setState(() => _isListening = false);
      _playAnimation(allowedAnimations[0]);
    }
  }

//   Future<void> _processUserInput(String text) async {
//     if (text.isEmpty) return;
//     final sessionController =
//         Provider.of<SessionController>(context, listen: false);
//     await sessionController.addChildMessage(text);

//     try {
//       final promptContext = '''
// Child's message: $text

// Respond in Egyptian Arabic. Keep your response under 2-3 sentences.
// Be supportive and encouraging while focusing on the child's interests.
// ''';
//       final aiResponse = await _chatModel.sendMessage(promptContext);
//       await sessionController.addTherapistMessage(aiResponse);
//       await _speak(aiResponse);
//     } catch (e) {
//       const errorMsg = "عذراً، حدث خطأ أثناء معالجة طلبك.";
//       await sessionController.addTherapistMessage(errorMsg);
//       await _speak(errorMsg);
//     }
//   }

  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;
    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    await sessionController.addChildMessage(text);

    try {
      final promptContext = '''
Child's message: $text

Respond in Egyptian Arabic. Keep your response under 2-3 sentences.
Be supportive and encouraging while focusing on the child's interests.
''';

      // Pass child data on first message to set up context properly
      if (sessionController.state.conversation.length <= 1) {
        // First user message after initial system message
        final aiResponse = await _chatModel.sendMessage(promptContext,
            childData: widget.childData);
        await sessionController.addTherapistMessage(aiResponse);
        await _speak(aiResponse);
      } else {
        final aiResponse = await _chatModel.sendMessage(promptContext);
        await sessionController.addTherapistMessage(aiResponse);
        await _speak(aiResponse);
      }
    } catch (e) {
      const errorMsg = "عذراً، حدث خطأ أثناء معالجة طلبك.";
      await sessionController.addTherapistMessage(errorMsg);
      await _speak(errorMsg);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isSpeaking && mounted) {
      setState(() => _isSpeaking = true);
      _playAnimation(allowedAnimations[1]);
      await _ttsService.speak(text);
    }
  }

  Future<void> _endCall() async {
    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    if (_isListening) await _speech.stop();
    if (_isSpeaking) await _ttsService.stop();

    final goodbyeMessage =
        _childName != null ? "الى اللقاء $_childName" : "الى اللقاء";
    await sessionController.addTherapistMessage(goodbyeMessage);

    setState(() {
      _isListening = false;
      _isSpeaking = true;
    });

    _playAnimation(allowedAnimations[1]);
    await _ttsService.speak(goodbyeMessage);

    setState(() {
      _callStarted = false;
      _isSpeaking = false;
    });

    _playAnimation(allowedAnimations[0]);

    try {
      final stats = await sessionController.endSession(_detectionStats);
      if (mounted) _showSessionSummary(stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error ending session: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showSessionSummary(SessionStatistics stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session #${stats.sessionNumber}'),
              Text('Duration: ${stats.sessionDuration.inMinutes} minutes'),
              Text('Total Messages: ${stats.totalMessages}'),
              Text('Child Messages: ${stats.childMessages}'),
              Text('Therapist Messages: ${stats.drMessages}'),
              Text('Average Words/Message: ${stats.wordsPerMessage}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.onModelLoaded.removeListener(_onModelLoaded);
    _speech.stop();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionController = Provider.of<SessionController>(context);
    final sessionState = sessionController.state;

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionState.sessionNumber > 0
            ? 'Session #${sessionState.sessionNumber}'
            : '3D Voice Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Flutter3DViewer(
                  src: 'assets/models/banotamixamonewtalk.glb',
                  controller: controller,
                  activeGestureInterceptor: true,
                  onProgress: (progress) {
                    setState(() {
                      isLoading = progress < 1;
                    });
                  },
                  onLoad: (modelAddress) {},
                  onError: (error) {
                    setState(() {
                      errorMessage = 'Failed to load model: $error';
                      isLoading = false;
                    });
                  },
                ),
                if (isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                if (errorMessage != null)
                  Container(
                    color: Colors.black45,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessionState.conversation.length,
              itemBuilder: (context, index) {
                final message = sessionState.conversation[index];
                final isUser = message.containsKey('child');
                final text = isUser ? message['child']! : message['dr']!;

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (sessionState.status != SessionStatus.active) {
                  return Center(
                    child: sessionState.status == SessionStatus.error
                        ? Text(sessionState.errorMessage ?? 'Unknown error')
                        : const CircularProgressIndicator(),
                  );
                }

                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 3
                          : (constraints.maxWidth - 16) / 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSpeaking ? null : _toggleListening,
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                        label: Text(_isListening ? 'Recording...' : 'Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isListening ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 3
                          : (constraints.maxWidth - 16) / 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSpeaking
                            ? () async {
                                await _ttsService.stop();
                                setState(() => _isSpeaking = false);
                                _playAnimation(allowedAnimations[0]);
                              }
                            : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop TTS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth - 16,
                      child: ElevatedButton.icon(
                        onPressed: _endCall,
                        icon: const Icon(Icons.call_end),
                        label: const Text('End Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
