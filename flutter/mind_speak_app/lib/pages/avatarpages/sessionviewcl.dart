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

class SessionView extends StatefulWidget {
  final String initialPrompt;
  final String initialResponse;
  final Map<String, dynamic> childData;
  final ChatGptTtsService? preloadedTtsService;
  final AvatarModel? avatar;

  const SessionView({
    super.key,
    required this.initialPrompt,
    required this.initialResponse,
    required this.childData,
    this.preloadedTtsService,
    this.avatar,
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
  Timer? _ttsWatchdogTimer;

  late AiService _aiService;
  late DetectionController _detectionController;
  late ChatGptModel _chatModel;
  late String? _sessionId;
  late AvatarModel _avatar;

  // Camera variables
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  Timer? _frameTimer;
  bool _isRecording = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _childName;
  String? _voiceEmotion;
  String? _facialEmotion;

  late ChatGptTtsService _ttsService;
  DateTime? _gameStartTime;
  int _currentLevel = 1;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  bool _isGameInitialized = false;
  String _currentAnimation = "idle";
  DateTime _lastAnimationChange = DateTime.now();

  // Track consecutive TTS failures for diagnostics
  int _ttsFailureCount = 0;

  @override
  void initState() {
    super.initState();
    print("DEBUG: SessionView initState started");

    // Use pre-loaded TTS if provided, otherwise create a new one
    _ttsService = widget.preloadedTtsService ?? ChatGptTtsService();

    // Initialize TTS with common phrases
    if (widget.preloadedTtsService == null) {
      _ttsService.initialize().then((_) {
        print("DEBUG: TTS service ready with preloaded phrases");
      });
    } else {
      print("DEBUG: Using pre-loaded TTS service");
    }

    // Set avatar
    _avatar = widget.avatar ?? Provider.of<AvatarModel>(context, listen: false);
    print(
        "DEBUG: Using avatar: ${_avatar.name} with model ${_avatar.modelPath}");

    // Configure TTS callbacks
    _setupTtsCallbacks();

    // Start TTS watchdog timer
    _setupTtsWatchdog();

    // Create game manager
    _gameManager = GameManager(ttsService: _ttsService);
    print("DEBUG: GameManager instance created");

    // Initialize session
    _initializeSession();

    // Initialize game
    _initializeGame();

    // Start stats update timer
    _startStatsUpdateTimer();

    // Preload game assets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameManager.preloadGameAssets(context);
      print("DEBUG: Game assets preloading started");
    });
  }

  void _setupTtsCallbacks() {
    // Setup TTS completion handler
    _ttsService.setCompletionHandler(() {
      print("🎤 TTS completion handler called");
      if (mounted) {
        setState(() => _isSpeaking = false);
        _playAnimation(_avatar.idleAnimation);
      }
    });

    // Setup TTS cancel handler
    _ttsService.setCancelHandler(() {
      print("🎤 TTS cancel handler called");
      if (mounted) {
        setState(() => _isSpeaking = false);
        _playAnimation(_avatar.idleAnimation);
      }
    });

    // Setup TTS start handler
    _ttsService.setStartPlaybackHandler(() {
      print("🎤 TTS start playback handler called");
      if (mounted) {
        _playAnimation(_avatar.talkingAnimation);
      }
    });
  }

  void _setupTtsWatchdog() {
    // Create a watchdog timer to detect and recover from TTS issues
    _ttsWatchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;

      // Check for inconsistent state - UI thinks it's speaking but TTS is not active
      if (_isSpeaking && !_ttsService.isPlaying) {
        final stuckDuration = DateTime.now().difference(_lastAnimationChange);

        // Only act if stuck for more than 3 seconds
        if (stuckDuration.inSeconds > 3) {
          print(
              "⚠️ WATCHDOG: TTS state mismatch detected - UI speaking but TTS not active for ${stuckDuration.inSeconds}s");
          _logTtsState();

          // Perform recovery
          _resetTtsState();
        }
      }
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
      // Play initial idle animation
      _playAnimation(_avatar.idleAnimation);

      // Log available animations for debugging
      print("🎭 Loaded avatar: ${_avatar.name} with animations:");
      print("   - idle: '${_avatar.idleAnimation}'");
      print("   - talking: '${_avatar.talkingAnimation}'");

      if (widget.initialResponse.isNotEmpty) {
        // Add a slight delay to ensure the UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _speak(widget.initialResponse);
          }
        });
      } else {
        debugPrint('Warning: Empty initial response provided');
      }
    }
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
          _playAnimation(_avatar.idleAnimation);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        _playAnimation(_avatar.idleAnimation);
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

  Future<void> _resetTtsState() async {
    print("🔄 Resetting TTS state");

    // First, try to stop the TTS service
    await _ttsService.stop();

    // Reset UI state
    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });

      // Reset animation
      _playAnimation(_avatar.idleAnimation);
    }

    // Small delay to ensure stable state
    await Future.delayed(const Duration(milliseconds: 300));

    print("✅ TTS state reset complete");
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

    print("🗣️ Processing user input: \"$text\"");
    _logTtsState();

    // Ensure we're in a clean state before starting
    if (_isSpeaking) {
      print("⚠️ Already speaking, resetting state first");
      await _resetTtsState();
    }

    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    await sessionController.addChildMessage(text);
    await _recordAndAnalyzeVoice(text);

    try {
      final prompt =
          "Child's message: $text\n\nRespond in Egyptian Arabic. Be encouraging, short, and positive.";
      print(
          "💬 Sending message to AI: \"${prompt.substring(0, min(50, prompt.length))}...\"");

      final aiResponse =
          await _chatModel.sendMessage(prompt, childData: widget.childData);
      print(
          "💬 Received AI response: \"${aiResponse.substring(0, min(50, aiResponse.length))}...\"");

      await sessionController.addTherapistMessage(aiResponse);

      // Speak the response
      await _speak(aiResponse);
    } catch (e) {
      print("❌ Error in _processUserInput: $e");
      const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      await sessionController.addTherapistMessage(errorMsg);

      // Reset state before trying to speak the error
      await _resetTtsState();
      await _speak(errorMsg);
    }
  }

  void _logTtsState() {
    print("🔍 TTS STATE DIAGNOSTIC:");
    print("  _isSpeaking: $_isSpeaking");
    print("  _ttsService.isPlaying: ${_ttsService.isPlaying}");
    print("  _currentAnimation: $_currentAnimation");
    print("  _ttsFailureCount: $_ttsFailureCount");
  }

  Future<void> _speak(String text) async {
    if (mounted) {
      try {
        print("🎤 Starting speak method");
        print(
            "🎤 Current state: _isSpeaking=$_isSpeaking, ttsService.isPlaying=${_ttsService.isPlaying}");

        // Ensure we're not already speaking
        if (_isSpeaking) {
          await _ttsService.stop();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        setState(() => _isSpeaking = true);
        _playAnimation(_avatar.talkingAnimation);

        print(
            'Starting TTS for text: "${text.substring(0, min(30, text.length))}..."');

        // Set up a safety timer in case TTS gets stuck
        final safetyTimer = Timer(const Duration(seconds: 10), () {
          if (mounted && _isSpeaking && !_ttsService.isPlaying) {
            print("⚠️ Safety timer triggered - TTS may be stuck");
            _logTtsState();
            _resetTtsState();
          }
        });

        try {
          await _ttsService.speak(text);
          _ttsFailureCount = 0; // Reset failure count on success
          print('TTS speak method completed successfully');
        } catch (e) {
          print("❌ TTS speak error: $e");
          _ttsFailureCount++;

          if (_ttsFailureCount >= 3) {
            print("⚠️ Multiple TTS failures detected, performing deeper reset");
            // More aggressive state reset could be implemented here
          }

          throw e; // Re-throw to ensure finally block handles cleanup
        } finally {
          safetyTimer.cancel(); // Clean up timer regardless of outcome
        }
      } catch (e) {
        print('❌ Error in TTS service: $e');

        // Ensure state is reset even on error
        if (mounted) {
          setState(() => _isSpeaking = false);
          _playAnimation(_avatar.idleAnimation);
        }
      }
    } else {
      print('⚠️ Widget not mounted, skipping TTS');
    }
  }

  void _playAnimation(String animation) {
    try {
      // Skip if the animation name is empty
      if (animation.trim().isEmpty) {
        print("⚠️ Warning: Empty animation name provided");
        return;
      }

      // Only play if different from current or it's a talking animation
      if (_currentAnimation != animation ||
          animation == _avatar.talkingAnimation) {
        print("🎭 Playing animation: $animation");
        controller.playAnimation(animationName: animation);
        _currentAnimation = animation;
        _lastAnimationChange = DateTime.now();
      } else {
        print("🎭 Animation skipped (duplicate): $animation");
      }
    } catch (e) {
      print('❌ Animation error: $e');
    }
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

  // Improved game initialization with clear null check
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
    _ttsWatchdogTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;
    final screenSize = MediaQuery.of(context).size;

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
            : [
                primaryColor,
                primaryColor.withAlpha(229), // 0.9 * 255 = 229
              ],
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
                // Avatar section
                Expanded(
                  flex: 3,
                  child: RepaintBoundary(
                    key: _avatarKey,
                    child: Flutter3DViewer(
                      src: _avatar.modelPath,
                      controller: controller,
                      activeGestureInterceptor: true,
                    ),
                  ),
                ),

                // Points display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  width: double.infinity,
                  child: Text(
                    "Total Points: $_totalScore",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                // Controls section - all wrapped in a responsive container
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Talk button - full width
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_isListening) {
                              final available = await _speech.initialize();
                              if (available) {
                                setState(() => _isListening = true);
                                _playAnimation(_avatar.idleAnimation);
                                await _speech.listen(
                                  onResult: (result) {
                                    if (result.finalResult) {
                                      _processUserInput(result.recognizedWords);
                                      setState(() => _isListening = false);
                                    }
                                  },
                                  listenMode: stt.ListenMode.dictation,
                                  partialResults: true,
                                  localeId: 'ar-EG',
                                );
                              }
                            } else {
                              await _speech.stop();
                              setState(() => _isListening = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.grey[800] : primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _isListening ? "Recording..." : "Start Talking",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Action buttons - always horizontal with scrolling if needed
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Game button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _resetGame();
                                  _gameManager.startGame(context, 1);
                                },
                                icon: const Icon(Icons.games, size: 20),
                                label: const Text("Play Game 🎮"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDark ? Colors.grey[800] : primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Stop TTS button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isSpeaking
                                    ? () async {
                                        await _ttsService.stop();
                                        setState(() => _isSpeaking = false);
                                        _playAnimation(_avatar.idleAnimation);
                                      }
                                    : null,
                                icon: const Icon(Icons.stop, size: 20),
                                label: const Text("Stop TTS"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDark ? Colors.grey[800] : primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // End Call button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _endSession,
                                icon: const Icon(Icons.call_end, size: 20),
                                label: const Text("End Call"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Debug reset button - made less prominent
                      SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: _resetGame,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          child: const Text("Reset Score"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Hidden camera
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

//
}


