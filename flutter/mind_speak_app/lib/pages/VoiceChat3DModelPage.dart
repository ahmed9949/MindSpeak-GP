// lib/screens/voice_chat_3d_model_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:mind_speak_app/models/sessionmodel.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/servicemanager.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class VoiceChat3DModelPage extends StatefulWidget {
  final Map<String, dynamic> childData;
  final String initialPrompt;
  final String initialResponse;

  const VoiceChat3DModelPage({
    Key? key,
    required this.childData,
    required this.initialPrompt,
    required this.initialResponse,
  }) : super(key: key);

  @override
  State<VoiceChat3DModelPage> createState() => _VoiceChat3DModelPageState();
}

class _VoiceChat3DModelPageState extends State<VoiceChat3DModelPage> {
  // === 3D Model & Animation ===
  final Flutter3DController controller = Flutter3DController();
  bool isModelLoaded = false;
  bool isLoading = true;
  String? errorMessage;
  final List<String> allowedAnimations = ['Rig|idle', 'Rig|cycle_talking'];

  // === Voice Conversation Variables ===
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _callStarted = false;
  String? _childName;
  late String _sessionId;
  late DateTime _sessionStartTime;
  int _sessionNumber = 0;
  late GenerativeModel _model;
  late ChatSession _chatSession;
  late SessionAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _sessionStartTime = DateTime.now();
    _childName = widget.childData['name'];

    // Initialize all components
    _initGenerativeModel();
    _initSpeech();
    _initTts();

    // Add 3D model listener
    controller.onModelLoaded.addListener(_onModelLoaded);
  }

  void _initGenerativeModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    _analyzer = SessionAnalyzer(_model);

    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    if (sessionProvider.childId != null) {
      _chatSession = ChatManager.getOrCreateSession(
          sessionProvider.childId!, _model, widget.childData);
    }
  }

  Future<int> _getAndIncrementSessionCounter() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final childId = sessionProvider.childId;

    try {
      final childRef =
          FirebaseFirestore.instance.collection('child').doc(childId);

      return await FirebaseFirestore.instance
          .runTransaction<int>((transaction) async {
        final childDoc = await transaction.get(childRef);

        if (!childDoc.exists) {
          throw Exception('Child document not found');
        }

        final currentCount = childDoc.data()?['sessionCount'] as int? ?? 0;
        final newCount = currentCount + 1;

        transaction.update(childRef, {'sessionCount': newCount});

        return newCount;
      });
    } catch (e) {
      print('Error incrementing session counter: $e');
      return 0;
    }
  }

  Future<void> _saveMessageToDatabase(String speaker, String message) async {
    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_sessionId)
          .set({
        'conversation': FieldValue.arrayUnion([
          {speaker: message}
        ]),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving message to database: $e');
    }
  }

  Future<void> _startCall() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    if (sessionProvider.isLoggedIn && sessionProvider.userId != null) {
      try {
        _sessionNumber = await _getAndIncrementSessionCounter();

        // Get therapistId from child data
        String therapistId = widget.childData['therapistId'];

        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_sessionId)
            .set({
          'sessionId': _sessionId,
          'childId': sessionProvider.childId,
          'therapistId': therapistId,
          'startTime': _sessionStartTime.toIso8601String(),
          'sessionNumber': _sessionNumber,
          'conversation': [],
        });

        // Generate welcome message using chat session
        await _saveMessageToDatabase('dr', widget.initialResponse);

        setState(() {
          _messages.add(ChatMessage(
            text: widget.initialResponse,
            isUser: false,
          ));
        });

        await _speak(widget.initialResponse);
      } catch (e) {
        print("Error starting call: $e");
        const errorMsg = "عذراً، حدث خطأ في بدء المحادثة.";
        setState(() {
          _messages.add(ChatMessage(text: errorMsg, isUser: false));
        });
        await _speak(errorMsg);
      }
    }
  }

  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      setState(() {
        isModelLoaded = true;
        isLoading = false;
      });
      _playAnimation('Rig|idle');
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
    await _flutterTts.setSpeechRate(0.9);
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

  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    await _saveMessageToDatabase('child', text);

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });

    try {
      if (_chatSession == null) {
        throw Exception('Chat session not initialized');
      }

      String aiResponse = await ChatManager.processResponse(
          _chatSession, text, _messages.length);

      // Ensure response is not too long
      if (aiResponse.split('.').length > 2) {
        aiResponse = aiResponse
                .split('.')
                .take(2)
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .join('. ') +
            '.';
      }

      await _saveMessageToDatabase('dr', aiResponse);

      setState(() {
        _messages.add(ChatMessage(text: aiResponse, isUser: false));
      });

      await _speak(aiResponse);
    } catch (e) {
      print("Error processing input: $e");
      const errorMsg = "عذراً، حدث خطأ أثناء معالجة طلبك.";
      setState(() {
        _messages.add(ChatMessage(text: errorMsg, isUser: false));
      });
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

  Future<SessionStatistics> _calculateSessionStatistics() async {
    int childMsgCount = 0;
    int drMsgCount = 0;
    int totalWords = 0;

    for (var message in _messages) {
      if (message.isUser) {
        childMsgCount++;
      } else {
        drMsgCount++;
      }
      totalWords += message.text.split(' ').length;
    }

    return SessionStatistics(
      totalMessages: _messages.length,
      childMessages: childMsgCount,
      drMessages: drMsgCount,
      sessionDuration: DateTime.now().difference(_sessionStartTime),
      sessionDate: _sessionStartTime,
      wordsPerMessage: totalWords ~/ _messages.length,
      sessionNumber: _sessionNumber,
    );
  }

  Future<void> _saveSessionStatistics() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final stats = await _calculateSessionStatistics();

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_sessionId)
          .update({
        'statistics': stats.toJson(),
        'endTime': DateTime.now().toIso8601String(),
      });

      final childRef = FirebaseFirestore.instance
          .collection('child')
          .doc(sessionProvider.childId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final childDoc = await transaction.get(childRef);

        if (!childDoc.exists) return;

        final currentStats = childDoc.data()?['aggregateStats'] ??
            {
              'totalSessions': 0,
              'totalMessages': 0,
              'averageSessionDuration': 0,
              'averageMessagesPerSession': 0,
            };

        final newTotalSessions = (currentStats['totalSessions'] as int) + 1;
        final newTotalMessages =
            (currentStats['totalMessages'] as int) + stats.totalMessages;
        final newAvgDuration =
            ((currentStats['averageSessionDuration'] as int) *
                        (newTotalSessions - 1) +
                    stats.sessionDuration.inMinutes) /
                newTotalSessions;
        final newAvgMessages = newTotalMessages / newTotalSessions;

        transaction.update(childRef, {
          'aggregateStats': {
            'totalSessions': newTotalSessions,
            'totalMessages': newTotalMessages,
            'averageSessionDuration': newAvgDuration.round(),
            'averageMessagesPerSession': newAvgMessages.round(),
            'lastSessionDate': DateTime.now().toIso8601String(),
          }
        });
      });
    } catch (e) {
      print('Error saving session statistics: $e');
    }
  }

// In voice_chat_3d_model_page.dart
 Future<void> _generateAndSaveRecommendations() async {
  final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
  final childId = sessionProvider.childId;

  if (childId == null) return;

  try {
    // Get recent sessions
    final sessions = await FirebaseFirestore.instance
        .collection('sessions')
        .where('childId', isEqualTo: childId)
        .orderBy('sessionNumber', descending: true)
        .limit(5)  // Get last 5 sessions
        .get();

    if (sessions.docs.isEmpty) {
      print('No sessions found for recommendations');
      return;
    }

    // Get child data for recommendations
    final childDoc = await FirebaseFirestore.instance
        .collection('child')
        .doc(childId)
        .get();

    if (!childDoc.exists) {
      print('Child document not found');
      return;
    }

    final childData = childDoc.data()!;
    final sessionData = sessions.docs.map((doc) => doc.data()).toList();
    final aggregateStats = childData['aggregateStats'] ?? {};

    // Generate recommendations with more specific prompt
    final prompt = '''
Based on the session data for ${childData['name']}, aged ${childData['age']}, with interest in ${childData['childInterest']},
please provide two specific recommendations in Arabic:

1. Recommendations for parents (2-3 sentences):
- How to support the child at home
- Activities to try
- Areas to focus on

2. Recommendations for therapists (2-3 sentences):
- Therapeutic strategies
- Progress notes
- Focus areas for next session
''';

    final chat = _model.startChat();
    final response = await chat.sendMessage(Content.text(prompt));
    
    if (response.text == null) {
      print('No recommendations generated');
      return;
    }

    // Split recommendations
    final recommendationsText = response.text!;
    final parts = recommendationsText.split('2.');
    final parentRecs = parts[0].replaceAll('1.', '').trim();
    final therapistRecs = parts.length > 1 ? parts[1].trim() : '';

    final recommendations = {
      'parents': parentRecs,
      'therapists': therapistRecs,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save to session document
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(_sessionId)
        .update({
          'recommendations': recommendations,
        });

    // Save to child document
    await FirebaseFirestore.instance
        .collection('child')
        .doc(childId)
        .update({
          'latestRecommendations': recommendations,
        });

    print('Recommendations saved successfully');
  } catch (e) {
    print('Error generating recommendations: $e');
  }
}
  Future<void> _endCall() async {
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
    await _saveMessageToDatabase('dr', endingMessage);
 

    setState(() {
      _messages.add(ChatMessage(text: endingMessage, isUser: false));
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

    // Save statistics first
  await _saveSessionStatistics();
  
  // Then generate and save recommendations
  await _generateAndSaveRecommendations();


    if (mounted) {
      // Show session summary dialog
      showDialog(
        context: context,
        builder: (context) => FutureBuilder<SessionStatistics>(
          future: _calculateSessionStatistics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                title: Text('Calculating Statistics...'),
                content: CircularProgressIndicator(),
              );
            }

            final stats = snapshot.data!;
            return AlertDialog(
              title: const Text('Session Summary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session #${stats.sessionNumber}'),
                    Text(
                        'Duration: ${stats.sessionDuration.inMinutes} minutes'),
                    Text('Total Messages: ${stats.totalMessages}'),
                    Text('Child Messages: ${stats.childMessages}'),
                    Text('Therapist Messages: ${stats.drMessages}'),
                    Text('Average Words/Message: ${stats.wordsPerMessage}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        ),
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _sessionNumber > 0 ? 'Session #$_sessionNumber' : '3D Voice Chat'),
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color:
                          message.isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Text(
                      message.text,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              },
            ),
          ),
          // Control Buttons Section
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_callStarted)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _callStarted = true;
                      });
                      _startCall();
                    },
                    child: const Text("Start Call"),
                  )
                else ...[
                  // Record Button
                  ElevatedButton.icon(
                    onPressed: _isSpeaking ? null : _toggleListening,
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    label: Text(_isListening ? 'Recording...' : 'Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : Colors.blue,
                    ),
                  ),
                  // Stop TTS Button
                  ElevatedButton.icon(
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
                    ),
                  ),
                  // End Call Button
                  ElevatedButton.icon(
                    onPressed: () => _endCall(),
                    icon: const Icon(Icons.call_end),
                    label: const Text('End Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
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
  const ChatMessage({required this.text, required this.isUser});
}
