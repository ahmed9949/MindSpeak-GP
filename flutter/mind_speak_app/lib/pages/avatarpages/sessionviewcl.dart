// lib/views/session/session_view.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mind_speak_app/models/session_statistics.dart';
import 'package:mind_speak_app/models/sessionstate.dart';
import 'package:mind_speak_app/service/avatarservice/conversationsetup.dart';
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
  // === 3D Model & Animation ===
  final Flutter3DController controller = Flutter3DController();
  bool isModelLoaded = false;
  bool isLoading = true;
  String? errorMessage;
  final List<String> allowedAnimations = ['Rig|idle', 'Rig|cycle_talking'];

  // === Voice Conversation Variables ===
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _callStarted = false;
  String? _childName;

  // Detection-related data (simplified for this example)
  final Map<String, dynamic> _detectionStats = {};

  @override
  void initState() {
    super.initState();
    _childName = widget.childData['name'];

    // Initialize all components
    _initSpeech();
    _initTts();

    // Add 3D model listener
    controller.onModelLoaded.addListener(_onModelLoaded);

    // Mark session as started after initialization
    _callStarted = true;
  }

  // === Speech & TTS Methods ===

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() => _isListening = false);
            _playAnimation('Rig|idle');
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _playAnimation('Rig|idle');
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _playAnimation('Rig|idle');
      }
    });
  }

  Future<void> _toggleListening() async {
    try {
      if (!_isListening) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _playAnimation('Rig|idle');
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
        _playAnimation('Rig|idle');
      }
    } catch (e) {
      setState(() => _isListening = false);
      _playAnimation('Rig|idle');
    }
  }

  // === 3D Model Methods ===

  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      setState(() {
        isModelLoaded = true;
        isLoading = false;
      });
      _playAnimation('Rig|idle');

      // Speak the initial response when model is loaded
      if (widget.initialResponse.isNotEmpty) {
        _speak(widget.initialResponse);
      }
    }
  }

  void _playAnimation(String animationName) {
    try {
      controller.playAnimation(animationName: animationName);
      if (animationName == 'Rig|cycle_talking') {
        controller.setCameraTarget(0, 1.7, 0);
        controller.setCameraOrbit(0, 90, 3);
      } else {
        controller.resetCameraTarget();
        controller.resetCameraOrbit();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Animation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // === Conversation Processing ===
  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    final sessionController =
        Provider.of<SessionController>(context, listen: false);

    // Add child message to session
    await sessionController.addChildMessage(text);

    try {
      // Use the session controller to process the message with your existing AI setup
      final model = ConversationModule.createGenerativeModel();
      final chat = model.startChat();

      // Create a context-aware prompt
      final promptContext = '''
Child's message: $text

Respond in Egyptian Arabic. Keep your response under 2-3 sentences.
Be supportive and encouraging while focusing on the child's interests.
''';

      final response = await chat.sendMessage(Content.text(promptContext));
      final aiResponse = response.text ?? "عذراً، حدث خطأ في توليد الرد.";

      // Add therapist/AI message to session
      await sessionController.addTherapistMessage(aiResponse);

      // Speak the response
      await _speak(aiResponse);
    } catch (e) {
      print("Error processing input: $e");
      const errorMsg = "عذراً، حدث خطأ أثناء معالجة طلبك.";
      await sessionController.addTherapistMessage(errorMsg);
      await _speak(errorMsg);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isSpeaking && mounted) {
      setState(() => _isSpeaking = true);
      _playAnimation('Rig|cycle_talking');
      await _flutterTts.speak(text);
    }
  }

  // === Session Management ===

  Future<void> _endCall() async {
    final sessionController =
        Provider.of<SessionController>(context, listen: false);

    if (_isListening) {
      await _speech.stop();
    }
    if (_isSpeaking) {
      await _flutterTts.stop();
    }

    String endingMessage = "الى اللقاء";
    if (_childName != null) {
      endingMessage = "الى اللقاء $_childName";
    }

    // Save ending message
    await sessionController.addTherapistMessage(endingMessage);

    setState(() {
      _isListening = false;
      _isSpeaking = true;
    });

    _playAnimation('Rig|cycle_talking');
    await _flutterTts.speak(endingMessage);

    setState(() {
      _callStarted = false;
      _isSpeaking = false;
    });

    _playAnimation('Rig|idle');

    try {
      // End session and get statistics
      final stats = await sessionController.endSession(_detectionStats);

      // Get the correct child ID - this is critical
      final childId = widget.childData['id'] ??
          ''; // Make sure this ID exists in your database

      if (childId.isEmpty) {
        // Log the error and skip recommendation generation
        print("Error: Cannot generate recommendations - missing childId");
      } else {
        // Generate recommendations with proper setup
        final model = ConversationModule.createGenerativeModel();
        final chat = model.startChat();

        final promptForRecommendations = '''
Based on a therapy session with a child who has autism:
- Child name: ${widget.childData['name'] ?? 'Unknown'}
- Age: ${widget.childData['age'] ?? 'Unknown'}
- Interests: ${widget.childData['childInterest'] ?? 'Unknown'}

Please provide two specific recommendations in Arabic:

1. For parents (2-3 sentences):
- How to support the child at home
- Activities to try

2. For therapists (2-3 sentences):
- Therapeutic strategies for future sessions
- Areas to focus on
''';

        try {
          final response =
              await chat.sendMessage(Content.text(promptForRecommendations));
          final recommendationsText = response.text ?? '';

          // Split the response into parent and therapist recommendations
          final parts = recommendationsText.split('2.');
          final parentsRec = parts[0].replaceAll('1.', '').trim();
          final therapistRec = parts.length > 1 ? parts[1].trim() : '';

          // Save recommendations directly to the session document instead of updating child
          await sessionController.generateRecommendations(
              childId, parentsRec, therapistRec);
        } catch (e) {
          print("Error generating recommendations: $e");
        }
      }

      // Show session summary dialog
      if (mounted) {
        _showSessionSummary(stats);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ending session: $e'),
          backgroundColor: Colors.red,
        ),
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
              Navigator.of(context).pop(); // Return to previous screen
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
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the session controller to get current state
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
          // 3D Model Viewer Section
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Flutter3DViewer(
                  src: 'assets/models/business_man.glb',
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

          // Chat Messages Section
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

          // Control Buttons Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (sessionState.status != SessionStatus.active) {
                  // Show loading state or error
                  return Center(
                    child: sessionState.status == SessionStatus.error
                        ? Text(sessionState.errorMessage ?? 'Unknown error')
                        : const CircularProgressIndicator(),
                  );
                }

                // Control buttons when session is active
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    // Record Button
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

                    // Stop TTS Button
                    SizedBox(
                      width: constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 3
                          : (constraints.maxWidth - 16) / 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSpeaking
                            ? () async {
                                await _flutterTts.stop();
                                setState(() => _isSpeaking = false);
                                _playAnimation('Rig|idle');
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

                    // End Call Button
                    SizedBox(
                      width: constraints.maxWidth > 600
                          ? (constraints.maxWidth - 32) / 3
                          : constraints.maxWidth - 16,
                      child: ElevatedButton.icon(
                        onPressed: () => _endCall(),
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

// This class needs to be in your SessionController
// If not already present, add this to your sessioncontrollerCl.dart file
// class SessionStatistics {
//   final int totalMessages;
//   final int childMessages;
//   final int drMessages;
//   final Duration sessionDuration;
//   final DateTime sessionDate;
//   final int wordsPerMessage;
//   final int sessionNumber;

//   SessionStatistics({
//     required this.totalMessages,
//     required this.childMessages,
//     required this.drMessages,
//     required this.sessionDuration,
//     required this.sessionDate,
//     required this.wordsPerMessage,
//     required this.sessionNumber,
//   });
// }
