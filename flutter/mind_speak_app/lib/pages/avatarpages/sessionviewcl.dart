import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:mind_speak_app/components/games/game_manager.dart';
import 'package:mind_speak_app/controllers/detectioncontroller.dart';
import 'package:mind_speak_app/models/avatar.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/service/avatarservice/flutterttsservice.dart';

class SessionView extends StatefulWidget {
  final String initialPrompt;
  final String initialResponse;
  final Map<String, dynamic> childData;
  final AvatarModel avatarModel;

  const SessionView({
    super.key,
    required this.initialPrompt,
    required this.initialResponse,
    required this.childData,
    required this.avatarModel,
  });

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final GlobalKey _avatarKey = GlobalKey();
  final Flutter3DController controller = Flutter3DController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late GameManager _gameManager;
  Timer? _statsUpdateTimer;

  late AiService _aiService;
  late DetectionController _detectionController;
  late ChatGptModel _chatModel;
  late String? _sessionId;

  // Camera variables
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  Timer? _frameTimer;
  bool _isRecording = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isThinking = false;
  String? _childName;
  String? _voiceEmotion;
  String? _facialEmotion;

  // final FlutterTtsService _ttsService = FlutterTtsService();

  final ChatGptTtsService _ttsService = ChatGptTtsService();
  DateTime? _gameStartTime;
  int _currentLevel = 1;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  bool _isGameInitialized = false;
  Timer? _silenceTimer;
  bool _isSilenceTimerActive = false;

  @override
  void initState() {
    super.initState();
    print("DEBUG: SessionView initState started");

    // Initialize TTS with common phrases
    _ttsService.initialize().then((_) {
      print("DEBUG: TTS service ready with preloaded phrases");
    });

    // Create GameManager first before initializing games
    _gameManager = GameManager(ttsService: _ttsService);
    print("DEBUG: GameManager instance created");

    // Initialize session after creating GameManager
    _initializeSession();

    // Initialize game AFTER GameManager is created
    _initializeGame();

    // Start periodic stats update
    _startStatsUpdateTimer();

    // Set up completion handler once during initialization
    _ttsService.setCompletionHandler(() {
      if (mounted) {
        print(
            "TTS completed, returning to idle animation and starting listening");
        setState(() => _isSpeaking = false);
        _playAnimation(widget.avatarModel.idleAnimation);

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isListening && !_isThinking) {
            _startListening();
          }
        });
      }
    });

    // Preload game assets for smoother performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameManager.preloadGameAssets(context);
      print("DEBUG: Game assets preloading started");
    });
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _isSilenceTimerActive = true;

    _silenceTimer = Timer(const Duration(seconds: 15), () {
      if (_isListening && _isSilenceTimerActive && mounted) {
        _handleSilence();
      }
    });
    print("DEBUG: Silence timer started (15 seconds)");
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _isSilenceTimerActive = false;
    print("DEBUG: Silence timer cancelled");
  }

  void _handleSilence() {
    if (!mounted) return;

    print("DEBUG: Silence detected for 15 seconds");

    // First stop the listening
    _speech.stop();
    setState(() => _isListening = false);

    // Prompt to play a game
    _speak("طيب تعالي نلعب لعبه").then((_) {
      // After speaking, start the game
      _resetGame();
      _gameManager.startGame(context, 1);
      print("DEBUG: Started game after silence");
    });
  }

  void _startStatsUpdateTimer() {
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _gameManager.isGameInProgress) {
        _syncGameStats();
      }
    });
  }

  void _syncGameStats() {
    setState(() {
      _totalScore = _gameManager.totalScore;
      _correctAnswers = _gameManager.correctAnswers;
      _wrongAnswers = _gameManager.wrongAnswers;
      _currentLevel = _gameManager.currentLevel;
    });
    print("DEBUG: Synced stats - Score: $_totalScore, Level: $_currentLevel");
  }

  Future<void> ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception("Camera permission denied");
      }
    }
  }

  Future<void> _initializeSession() async {
    try {
      await ensureCameraPermission();
      _chatModel = Provider.of<ChatGptModel>(context, listen: false);
      _aiService = AiService();
      _detectionController = DetectionController();
      _sessionId = Provider.of<SessionController>(context, listen: false)
          .state
          .sessionId;
      _childName = widget.childData['name'];
      controller.onModelLoaded.addListener(_onModelLoaded);
      await _initializeCamera();
      await _initSpeech();
      await _initRecorder();
      _startFrameTimer();
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      _cameraController = CameraController(
        frontCamera ?? cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController.initialize();
      setState(() => _isCameraInitialized = true);
      debugPrint('✅ Camera initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing camera: $e');
    }
  }

  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      print("3D Model loaded successfully");

      // Start with greeting animation first
      _playAnimation(widget.avatarModel.greetingAnimation);
      print("Playing greeting animation");

      // For the welcome message, add a delay to let the greeting animation play
      if (widget.initialResponse.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;

          print("Preparing to speak welcome message");
          _ttsService.setAudioReadyHandler(() {
            if (mounted) {
              print(
                  "Welcome message prep started, switching to talking animation");
              setState(() => _isSpeaking = true);
              _playAnimation(widget.avatarModel.talkingAnimation);
            }
          });

          // Note: We don't override the completion handler here anymore
          // since it's set once in initState to auto-start listening

          _speak(widget.initialResponse);
          // Listening will auto-start after welcome via the completion handler
        });
      }
    }
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
          if (!_isThinking && !_isSpeaking) {
            _playAnimation(widget.avatarModel.idleAnimation);
          }
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        if (!_isThinking && !_isSpeaking) {
          _playAnimation(widget.avatarModel.idleAnimation);
        }
      },
    );
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  void _startFrameTimer() {
    _frameTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _captureAndAnalyzeFrame();
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    try {
      if (!_isCameraInitialized || !_cameraController.value.isInitialized) {
        debugPrint('⚠️ Camera not initialized, skipping frame capture');
        return;
      }

      // Capture frame from camera
      final XFile imageFile = await _cameraController.takePicture();

      // Analyze the captured frame
      await _analyzeAllFrameData(File(imageFile.path));
    } catch (e) {
      debugPrint('❌ Error capturing frame: $e');
    }
  }

  Future<void> _analyzeAllFrameData(File frame) async {
    try {
      final detectionData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 👁️ 1. Eye Gaze Analysis (using base64)
      try {
        List<int> imageBytes = await frame.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        // Analyze gaze using base64 image
        final gazeResult = await _aiService.analyzeGazeFromBase64(base64Image);
        if (gazeResult != null) {
          detectionData['gaze'] = {
            'status': gazeResult['focus_status'] ?? 'Unknown',
            'focused_percentage': gazeResult['focused_percentage'] ?? 0,
            'not_focused_percentage': gazeResult['not_focused_percentage'] ?? 0,
          };

          // Update UI with focus status
          if (mounted) {
            if (gazeResult['focus_status']?.contains('Focused') ?? false) {
              // Only play idle animation if not in another state
              if (!_isSpeaking && !_isListening && !_isThinking) {
                _playAnimation(widget.avatarModel.idleAnimation);
              }
            } else {
              // Optional: Play a subtle "attention" animation if not focused
              // But don't interrupt other animations
              if (!_isSpeaking && !_isListening && !_isThinking) {
                _playAnimation(widget.avatarModel.idleAnimation);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error in gaze detection: $e');
      }

      // 🔍 2. Behavior Detection
      try {
        final behaviorResult = await _aiService.analyzeBehavior(frame);
        if (behaviorResult != null && behaviorResult['behavior'] != null) {
          detectionData['behavior'] = behaviorResult['behavior'];
        }
      } catch (e) {
        debugPrint('❌ Error in behavior detection: $e');
      }

      // 😊 3. Facial Emotion Detection
      try {
        final emotionResult = await _aiService.analyzeEmotionFromImage(frame);
        if (emotionResult != null && emotionResult['emotion'] != null) {
          detectionData['emotion'] = emotionResult['emotion'];
          setState(() => _facialEmotion = emotionResult['emotion']);
        }
      } catch (e) {
        debugPrint('❌ Error in emotion detection: $e');
      }

      // Log detection data to console
      debugPrint('Detection data: ${jsonEncode(detectionData)}');

      // ✅ Save to Firestore
      if (_sessionId != null) {
        await _detectionController.addDetection(
          sessionId: _sessionId!,
          detectionData: detectionData,
        );
      } else {
        debugPrint('❌ Cannot save detection: No session ID available');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _analyzeAllFrameData: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _recordAndAnalyzeVoice(String sttText) async {
    if (_isRecording) return;

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      debugPrint('🎙️ Starting voice recording...');
      setState(() => _isRecording = true);

      await _recorder.startRecorder(toFile: filePath);
      // Record for a few seconds to capture enough audio for analysis
      await Future.delayed(const Duration(seconds: 3));
      await _recorder.stopRecorder();

      final fileStats = await File(filePath).stat();
      debugPrint('🎙️ Voice recording completed: ${fileStats.size} bytes');

      // Analyze the voice recording
      final result = await _aiService.analyzeEmotionFromVoice(File(filePath));

      if (result != null && mounted) {
        debugPrint('🎧 Voice emotion detected: ${result['emotion']}');
        setState(() => _voiceEmotion = result['emotion']);

        // Save voice emotion detection to Firestore
        if (_sessionId != null) {
          await _detectionController.addDetection(
            sessionId: _sessionId!,
            detectionData: {
              'timestamp': DateTime.now().toIso8601String(),
              'voiceEmotion': result['emotion'],
              'speechText': sttText,
            },
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Voice analysis error: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() => _isRecording = false);

      // Clean up the temporary file
      try {
        if (await File(filePath).exists()) {
          await File(filePath).delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up audio file: $e');
      }
    }
  }

  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    // Cancel silence timer during processing
    _cancelSilenceTimer();

    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    await sessionController.addChildMessage(text);
    await _recordAndAnalyzeVoice(text);

    try {
      // Show thinking animation while processing
      setState(() => _isThinking = true);
      _playAnimation(widget.avatarModel.thinkingAnimation);

      final prompt =
          "Child's message: $text\n\nRespond in Egyptian Arabic. Be encouraging, short, and positive.";
      final aiResponse =
          await _chatModel.sendMessage(prompt, childData: widget.childData);
      await sessionController.addTherapistMessage(aiResponse);

      // Set thinking to false before starting to speak
      setState(() => _isThinking = false);
      await _speak(aiResponse);

      // Note: Listening will auto-start after speaking via the completion handler
    } catch (e) {
      const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      await sessionController.addTherapistMessage(errorMsg);
      setState(() => _isThinking = false);
      await _speak(errorMsg);
    }
  }

  Future<void> _speak(String text) async {
    try {
      // Stop any current speech
      if (_isSpeaking) {
        await _ttsService.stop();
        setState(() => _isSpeaking = false);
      }

      if (mounted) {
        try {
          setState(() => _isSpeaking = true);

          // Set handlers to coordinate animations
          _ttsService.setAudioReadyHandler(() {
            if (mounted) {
              // Start the talking animation immediately when the handler is called
              print(
                  "Audio ready handler triggered, starting talking animation");
              _playAnimation(widget.avatarModel.talkingAnimation);
            }
          });

          // Note: Completion handler is now set once in initState

          print(
              "Starting TTS for: \"${text.substring(0, min(30, text.length))}...\"");
          await _ttsService.speak(text);
        } catch (e) {
          print("❌ Error in TTS service: $e");
          setState(() => _isSpeaking = false);
          _playAnimation(widget.avatarModel.idleAnimation);

          // Even on error, try to start listening
          if (mounted && !_isListening && !_isThinking) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _startListening();
            });
          }
        }
      }
    } catch (e) {
      print("❌ Error in _speak: $e");
      if (mounted) {
        setState(() => _isSpeaking = false);
        _playAnimation(widget.avatarModel.idleAnimation);
      }
    }
  }

  void _playAnimation(String animation) {
    controller.playAnimation(animationName: animation);
  }

  Future<void> _endSession() async {
    // Show loading indicator with optimized display
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return RepaintBoundary(
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Use optimized progress indicator
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3, // Smoother animation
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: const Text(
                      "Ending session...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // Use parallel async operations where possible
      final sessionController =
          Provider.of<SessionController>(context, listen: false);

      // Stop speech in parallel with other operations
      final speechStopFuture = _isListening ? _speech.stop() : Future.value();
      final ttsStopFuture = _isSpeaking ? _ttsService.stop() : Future.value();

      // Create goodbye message
      final goodbye =
          _childName != null ? "الى اللقاء $_childName" : "الى اللقاء";

      // Run operations in parallel where possible
      await Future.wait([
        speechStopFuture,
        ttsStopFuture,
        sessionController.addTherapistMessage(goodbye),
      ]);

      // Reset states
      setState(() {
        _isListening = false;
        _isSpeaking = false;
        _isThinking = false;
      });

      // Speak goodbye
      await _speak(goodbye);

      // Get detection summary in parallel with other operations
      final summaryFuture = _aiService.endConversationAndFetchSummary();

      // Calculate session time
      final int timeSpent = _gameStartTime != null
          ? DateTime.now().difference(_gameStartTime!).inSeconds
          : 0;

      // Get summary result
      final summary = await summaryFuture;
      if (summary != null && mounted) {
        await _detectionController.addDetection(
          sessionId: _sessionId!,
          detectionData: summary,
        );
      }

      // End session with optimized stats
      if (mounted) {
        await sessionController.endSession(
          {}, // detection stats
          totalScore: _totalScore,
          levelsCompleted: _currentLevel,
          correctAnswers: _correctAnswers,
          wrongAnswers: _wrongAnswers,
          timeSpent: timeSpent,
        );
      }

      // Generate recommendations in the background - don't wait for completion
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            final sessionData =
                await sessionController.getSessionById(_sessionId!);
            if (sessionData != null) {
              final childId = sessionData.childId;
              final allSessions =
                  await sessionController.getSessionsForChild(childId);
              final aggregateStats = widget.childData['aggregateStats'] ??
                  {
                    'totalSessions': 1,
                    'averageSessionDuration': 0,
                    'averageMessagesPerSession': 0
                  };

              final recommendations =
                  await Provider.of<SessionAnalyzerController>(context,
                          listen: false)
                      .generateRecommendations(
                childData: widget.childData,
                recentSessions: allSessions,
                aggregateStats: aggregateStats,
              );

              await sessionController.generateRecommendations(
                childId,
                recommendations['parents'] ?? '',
                recommendations['therapists'] ?? '',
              );
            }
          } catch (e) {
            print("Error generating recommendations: $e");
            // Continue without failing
          }
        }
      });

      // Close the loading dialog if still showing
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }

      // Navigate to the home page with optimized transition
      if (mounted) {
        navigator.pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = 0.0;
              const end = 1.0;
              const curve = Curves.easeInOut;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var fadeAnimation = animation.drive(tween);

              return FadeTransition(opacity: fadeAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print("❌ Error in _endSession: $e");

      // Close the loading dialog if still showing
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }

      // Still try to navigate home even with error, but with simpler transition
      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (_isSpeaking) {
      // Stop current speech to avoid overlap
      await _ttsService.stop();
      setState(() => _isSpeaking = false);
    }

    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _playAnimation(widget.avatarModel.idleAnimation);

        // Start the silence timer as soon as we start listening
        _startSilenceTimer();
        print("DEBUG: Started listening with silence detection");

        await _speech.listen(
          onResult: (result) {
            // Reset silence timer on any partial result (even non-final)
            if (result.recognizedWords.isNotEmpty) {
              _startSilenceTimer();
              print("DEBUG: Speech detected, restarting silence timer");
            }

            if (result.finalResult) {
              _cancelSilenceTimer();
              // Play thinking animation while processing the speech input
              _playAnimation(widget.avatarModel.thinkingAnimation);
              _processUserInput(result.recognizedWords);
              setState(() => _isListening = false);
              // Listening will restart after processing completes via the TTS completion handler
            }
          },
          listenMode: stt.ListenMode.dictation,
          partialResults: true, // Important to get intermediate results
          localeId: 'ar-EG',
        );
      } else {
        print("DEBUG: Speech recognition not available");
      }
    } else {
      // If we're already listening and the button is pressed,
      // stop listening and cancel silence timer
      await _speech.stop();
      _cancelSilenceTimer();
      setState(() => _isListening = false);
      print("DEBUG: Manually stopped listening");
    }
  }

  Future<void> _initializeGame() async {
    print("DEBUG: Initializing game connections");

    if (!mounted) {
      print("DEBUG: Widget not mounted during game initialization");
      return;
    }

    // Reset state to prevent double-counting
    setState(() {
      _totalScore = 0;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _currentLevel = 1;
    });

    await _gameManager.preloadGameAssets(context);

    // Clear out any previously registered callbacks first
    _gameManager.onGameCompleted = null;
    _gameManager.onGameFailed = null;
    _gameManager.onGameStatsUpdated = null;

    // Then register new callbacks
    _gameManager.onGameCompleted = (score, isLastLevel) {
      print(
          "DEBUG: onGameCompleted called with score=$score, isLastLevel=$isLastLevel");

      // Play clapping animation when a game is completed successfully
      _playAnimation(widget.avatarModel.clappingAnimation);

      // After clapping, show celebration message
      _ttsService.speak("برافو! أحسنت");

      // Return to idle animation after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isSpeaking && !_isListening && !_isThinking) {
          _playAnimation(widget.avatarModel.idleAnimation);
        }
      });

      // DON'T increment score here - use the GameManager's score directly
      setState(() {
        _totalScore = _gameManager.totalScore;
        _correctAnswers = _gameManager.correctAnswers;
        _wrongAnswers = _gameManager.wrongAnswers;
        if (!isLastLevel) _currentLevel = _gameManager.currentLevel;
      });

      print(
          "DEBUG: After completion: _totalScore=$_totalScore, level=$_currentLevel");
    };

    _gameManager.onGameFailed = () {
      print("DEBUG: onGameFailed called");

      // For wrong answers, don't change the animation
      // Just update the stats
      setState(() {
        _wrongAnswers = _gameManager.wrongAnswers;
      });
      print("DEBUG: After game failed: wrongAnswers=$_wrongAnswers");
    };

    _gameManager.onGameStatsUpdated = (score, correct, wrong) {
      print(
          "DEBUG: onGameStatsUpdated called with score=$score, correct=$correct, wrong=$wrong");
      setState(() {
        _totalScore = score;
        _correctAnswers = correct;
        _wrongAnswers = wrong;
      });
      print("DEBUG: After stats update: _totalScore=$_totalScore");
    };

    _isGameInitialized = true;
    print("DEBUG: Game initialization complete");
  }

  void _resetGame() {
    setState(() {
      _totalScore = 0;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _currentLevel = 1;
    });

    // Reset the GameManager state
    _gameManager.resetGame();
    print("DEBUG: Game state reset");
  }

  @override
  void dispose() {
    print("DEBUG: SessionView dispose called");
    _silenceTimer?.cancel();
    controller.onModelLoaded.removeListener(_onModelLoaded);
    _speech.stop();
    _ttsService.stop();
    _frameTimer?.cancel();
    _statsUpdateTimer?.cancel();
    _recorder.closeRecorder();
    _cameraController.dispose();
    _gameManager.dispose();
    super.dispose();
  }

  Widget _buildVoiceControlUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator text
          Text(
            _isListening
                ? "أنا أستمع إليك..."
                : (_isSpeaking
                    ? "أنا أتحدث..."
                    : (_isThinking ? "أنا أفكر..." : "...")),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          // Converted to stop/interrupt button
          ElevatedButton.icon(
            onPressed: () {
              if (_isListening) {
                _speech.stop();
                _cancelSilenceTimer();
                setState(() => _isListening = false);
              } else if (_isSpeaking) {
                _ttsService.stop();
                setState(() => _isSpeaking = false);
              }
              // Return to idle state
              _playAnimation(widget.avatarModel.idleAnimation);
            },
            icon: const Icon(Icons.stop_circle),
            label: const Text("إيقاف المحادثة"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    return Theme(
      data: themeProvider.currentTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Therapy Session"),
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[900]!, Colors.black]
                    : [primaryColor, primaryColor.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: RepaintBoundary(
                    key: _avatarKey,
                    child: Flutter3DViewer(
                      src: widget.avatarModel.modelPath,
                      controller: controller,
                      activeGestureInterceptor: true,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                   
                      const SizedBox(height: 6),
                      Text(
                        "Total Points: $_totalScore",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                // Replace this button with our new UI
                _buildVoiceControlUI(), // <-- HERE: This is the new UI
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ... your existing buttons ...
                    ElevatedButton.icon(
                      onPressed: _endSession,
                      icon: const Icon(Icons.call_end),
                      label: const Text("End Call"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: _isCameraInitialized
                      ? CameraPreview(_cameraController)
                      : Container(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
