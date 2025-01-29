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

// Local imports:
import 'package:mind_speak_app/audio/customesource.dart';
import 'package:mind_speak_app/components/chat_bubble.dart';
import 'package:mind_speak_app/models/message.dart';
import 'package:mind_speak_app/service/llmservice.dart';
import 'package:mind_speak_app/service/speechservice.dart';
import 'package:mind_speak_app/service/ttsService.dart';
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
  bool _isDetecting = false; // True if detection is running

  // We'll track how many frames captured for each endpoint
  int _totalFrames = 0;

  // Emotion detection
  final Map<String, int> _emotionCounts = {};
  String _lastEmotion = '';
  int _emotionChanges = 0;

  // Behavior detection
  final Map<String, int> _behaviorCounts = {};
  String _lastBehavior = '';
  int _behaviorChanges = 0;

  // We'll have two separate endpoints:
  final String _emotionUrl = 'http://172.20.10.3:5000/emotion-detection';
  final String _behaviorUrl = 'http://172.20.10.3:5001/analyze_frame';

  // ------------------ AUDIO / CHAT FIELDS ------------------
  final _sttService = STTService();
  final _ttsService = TTSService();
  final _chatService = ChatService();

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

  @override
  void initState() {
    super.initState();
    // Rive animations
    _talkController = OneShotAnimation('Talk', autoplay: false);
    _hearController = OneShotAnimation('hands_hear_start', autoplay: false);
    _stopHearController = OneShotAnimation('hands_hear_stop', autoplay: false);

    _initializeApp(); // STT + permissions
    _initializeCamera(); // Prepare camera for background detection (no preview)
  }

  // ------------------ PERMISSIONS, STT INIT ------------------
  Future<void> _initializeApp() async {
    try {
      await _checkPermissions();
      await _sttService.initialize(
        onError: (error) {
          _handleError('Speech error: ${error.errorMsg}');
          _endConversationSession();
        },
        onStatus: (status) {
          // handle STT status changes if needed
        },
      );
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

  // ------------------ CAMERA INIT (NO PREVIEW SHOWN) ------------------
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      // We won't display a preview, but the camera is ready for captures
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  // ------------------ START / STOP DETECTION ------------------
  void _startDetectionLoop() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDetecting) {
      return;
    }
    _isDetecting = true;
    _totalFrames = 0;

    // Reset counts
    _emotionCounts.clear();
    _emotionChanges = 0;
    _lastEmotion = '';

    _behaviorCounts.clear();
    _behaviorChanges = 0;
    _lastBehavior = '';

    // For example, capture frames every 5 seconds
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
      final Uint8List imageBytes = await file.readAsBytes();

      // We'll call 2 separate endpoints: one for emotion, one for behavior
      _detectEmotion(imageBytes);
      _detectBehavior(imageBytes);

      // Count total frames (just once each cycle)
      _totalFrames++;
    } catch (e) {
      debugPrint('Error capturing frame: $e');
    }
  }

  // -- EMOTION DETECTION --
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
        final emotion = data['emotion'] ?? '';

        if (!mounted) return;
        if (emotion.isNotEmpty) {
          setState(() {
            _emotionCounts[emotion] = (_emotionCounts[emotion] ?? 0) + 1;
            if (_lastEmotion.isNotEmpty && _lastEmotion != emotion) {
              _emotionChanges++;
            }
            _lastEmotion = emotion;
          });
        }
      } else {
        debugPrint('Emotion server error: ${resp.body}');
      }
    } catch (e) {
      debugPrint('detectEmotion error: $e');
    }
  }

  // -- BEHAVIOR DETECTION --
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
        final behavior = data['behavior'] ?? '';

        if (!mounted) return;
        if (behavior.isNotEmpty) {
          setState(() {
            _behaviorCounts[behavior] = (_behaviorCounts[behavior] ?? 0) + 1;
            if (_lastBehavior.isNotEmpty && _lastBehavior != behavior) {
              _behaviorChanges++;
            }
            _lastBehavior = behavior;
          });
        }
      } else {
        debugPrint('Behavior server error: ${resp.body}');
      }
    } catch (e) {
      debugPrint('detectBehavior error: $e');
    }
  }

  // ------------------ WELCOME MESSAGE FROM CHILD DATA ------------------
  Future<void> _autoWelcomeChild() async {
    try {
      final sessionProv = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessionProv.childId;
      if (childId == null) {
        // If no child, just say generic welcome
        await _processWithLLM("Hello there! How can I help you today?");
        return;
      }

      final childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        // If child doc not found, fallback
        await _processWithLLM("Hello there! How can I help you today?");
        return;
      }

      final data = childDoc.data()!;
      final childName = data['name'] ?? 'friend';

      final welcomePrompt = "Hello $childName! I'm here to chat with you. "
          "What are some of your favorite things to do or learn about?";

      // This calls LLM -> TTS -> etc.
      await _processWithLLM(welcomePrompt);
    } catch (e) {
      debugPrint("Error in _autoWelcomeChild: $e");
      await _processWithLLM("Hello! I'm here to help you today.");
    }
  }

  // ------------------ START / END SESSION ------------------
  void _startConversationSession() async {
    if (_isInSession) return;

    setState(() => _isInSession = true);

    // 1) Send welcome message (child name from DB)
    await _autoWelcomeChild();
    if (!mounted) return;

    // 2) Start detection loop
    _startDetectionLoop();

    // 3) Start STT
    _triggerAction(_hearController);
    _startContinuousListening();
  }

  Future<void> _endConversationSession() async {
    // 1) Stop detection
    _stopDetectionLoop();

    // 2) Save session
    await _saveSessionToFirestore();

    // 3) Stop STT
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

  // ------------------ LLM + TTS ------------------
  Future<void> _processWithLLM(String text) async {
    // Stop STT so TTS doesn't echo
    await _sttService.stopListening();

    try {
      final response = await _chatService.sendMessageToLLM(text);
      _addMessage(ChatMessage(text: response, isUser: false));

      // TTS
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

  // If user wants to skip TTS mid-response
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
      final sessionProv = Provider.of<SessionProvider>(context, listen: false);
      final childId = sessionProv.childId;
      if (childId == null) {
        debugPrint('No childId found; skipping save.');
        return;
      }

      final childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();
      if (!childDoc.exists) {
        debugPrint('Child doc not found; skipping save.');
        return;
      }

      final therapistId = childDoc.data()?['therapistId'] ?? '';

      final conversationText = _chatHistory.map((msg) {
        final who = msg.isUser ? 'User' : 'AI';
        return '$who: ${msg.text}';
      }).join('\n');

      final detectionData = _buildDetectionData();

      await FirebaseFirestore.instance.collection('session').add({
        'childId': childId,
        'therapistId': therapistId,
        'date': DateTime.now().toIso8601String(),
        'conversation': conversationText,
        'detectionduringsession': detectionData,
      });

      debugPrint('Session saved successfully to Firestore.');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Map<String, dynamic> _buildDetectionData() {
    // Compute emotion percentages
    final emotionPercentages = <String, double>{};
    _emotionCounts.forEach((key, count) {
      if (_totalFrames > 0) {
        emotionPercentages[key] = (count / _totalFrames) * 100;
      } else {
        emotionPercentages[key] = 0;
      }
    });

    // Compute behavior percentages
    final behaviorPercentages = <String, double>{};
    _behaviorCounts.forEach((key, count) {
      if (_totalFrames > 0) {
        behaviorPercentages[key] = (count / _totalFrames) * 100;
      } else {
        behaviorPercentages[key] = 0;
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
    // Stop detection if running
    _stopDetectionLoop();
    _cameraController?.dispose();

    // Cancel TTS subscription
    _playerSubscription?.cancel();
    _playerSubscription = null;

    // Stop STT
    _sttService.stopListening();
    _player.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No camera preview is displayed; detection is background only.
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Assistant + Dual Detection'),
      ),
      body: Column(
        children: [
          // 1) Rive animations
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

          // 2) Status text
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

          // 3) Show partial recognized text
          if (_currentBuffer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Heard so far: $_currentBuffer',
                style: const TextStyle(fontSize: 14.0),
              ),
            ),

          // 4) Chat messages
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

          // 5) Start/End + Interrupt buttons
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
