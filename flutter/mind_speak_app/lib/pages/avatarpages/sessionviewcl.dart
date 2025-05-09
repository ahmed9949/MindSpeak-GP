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
  final bool avatarPreloaded;
  final bool isFullyPreloaded; // New flag to indicate everything is ready

  const SessionView({
    super.key,
    required this.initialPrompt,
    required this.initialResponse,
    required this.childData,
    required this.avatarModel,
    this.avatarPreloaded = false,
    this.isFullyPreloaded = false,
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
  bool _isStartingGame = false;
  bool _welcomeMessagePlaying = false;

  late AiService _aiService;
  late DetectionController _detectionController;
  late ChatGptModel _chatModel;
  late String? _sessionId;
  bool _debugButtonPressed = false;
  String _lastButtonDebugMessage = "";

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
  Function? _completionHandler;

  // final FlutterTtsService _ttsService = FlutterTtsService();
  bool _isMicDisabledDuringGame = false;
  bool _showWaitingScreen = true;
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
    print("📱 SessionView initState started");

    // Check if we should skip waiting screen
    if (widget.isFullyPreloaded) {
      setState(() => _showWaitingScreen = false);
    }

    // Add a flag to track welcome message
    _welcomeMessagePlaying = true;

    // Initialize TTS with common phrases
    _ttsService.initialize().then((_) {
      print("✅ TTS service ready with preloaded phrases");
    });

    // Create GameManager first before initializing games
    _gameManager = GameManager(ttsService: _ttsService);
    print("📱 GameManager instance created");

    // Add callbacks for game events
    _gameManager.addGameStartedCallback(_onGameStarted);
    _gameManager.addGameEndedCallback(_onGameEnded);

    // Initialize session after creating GameManager
    _initializeSession();

    // Initialize game AFTER GameManager is created
    _initializeGame();

    // Start periodic stats update
    _startStatsUpdateTimer();

    // Store a reference to the completion handler
    _completionHandler = () {
      if (mounted) {
        try {
          print("🔊 TTS completed, resetting all states properly");
          // Reset all states to ensure clean state
          setState(() {
            _isSpeaking = false;
            _isThinking = false; // Make sure thinking is also reset
            _welcomeMessagePlaying = false; // Always clear this flag
          });
          _playAnimation(widget.avatarModel.idleAnimation);

          // Only start listening if not in a game and mic isn't disabled
          if (!_gameManager.isGameInProgress && !_isMicDisabledDuringGame) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted &&
                  !_isListening &&
                  !_isThinking &&
                  !_isSpeaking &&
                  !_isMicDisabledDuringGame) {
                print("🎤 Starting listening from completion handler");
                _startListening();
              }
            });
          }
        } catch (e) {
          print("❌ Error in TTS completion handler: $e");
        }
      }
    };

    // Set it in the TTS service
    _ttsService.setCompletionHandler(_completionHandler!);

    // Setup model loaded listener
    controller.onModelLoaded.addListener(_onModelLoaded);
  }

  Future<void> _simplifiedSpeak(String text) async {
    print("🎤 Using simplified speak method");

    // Reset all states first
    if (_isThinking) {
      setState(() => _isThinking = false);
    }

    // Stop any current audio
    await _ttsService.stop();

    // Show talking animation
    setState(() {
      _isSpeaking = true;
      _isListening = false;
    });
    _playAnimation(widget.avatarModel.talkingAnimation);

    // Don't need to manually set welcome mode here - it should be managed by _onModelLoaded
    // and other parts of the code when needed

    // Attempt to use TTS with a backup timer
    bool ttsFinished = false;

    // Set timeout to ensure we continue even if TTS fails silently
    Timer(Duration(seconds: 10), () {
      if (!ttsFinished && mounted) {
        print("⚠️ TTS timeout in simplified speak");

        // Force completion
        ttsFinished = true;
        setState(() {
          _isSpeaking = false;
          _isThinking = false;
        });
        _playAnimation(widget.avatarModel.idleAnimation);

        // Start listening again if not in welcome message or game mode
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted &&
              !_isListening &&
              !_isThinking &&
              !_isSpeaking &&
              !_welcomeMessagePlaying &&
              !_isMicDisabledDuringGame) {
            _startListening();
          }
        });
      }
    });

    // Try to speak
    try {
      print("🎤 TTS attempt: '$text'");
      await _ttsService.speak(text);
      ttsFinished = true;
      print("✅ TTS speak completed successfully");
    } catch (e) {
      print("❌ Error in simplified speak: $e");
      ttsFinished = true;

      // Ensure transition to listening
      setState(() {
        _isSpeaking = false;
        _isThinking = false;
      });
      _playAnimation(widget.avatarModel.idleAnimation);

      // Start listening again if appropriate
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted &&
            !_isListening &&
            !_isThinking &&
            !_isSpeaking &&
            !_welcomeMessagePlaying &&
            !_isMicDisabledDuringGame) {
          _startListening();
        }
      });
    }
  }
  // Add this method to check TTS API key
  // Future<void> _checkTtsApiKey() async {
  //   try {
  //     bool apiKeyValid = await _ttsService.validateApiKey();
  //     if (!apiKeyValid) {
  //       print("🔴 WARNING: TTS API key validation failed");

  //       // Show a warning to the user
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text(
  //                   "TTS API key may be invalid. Voice may not work properly."),
  //               duration: Duration(seconds: 5),
  //               action: SnackBarAction(
  //                 label: 'Dismiss',
  //                 onPressed: () {},
  //               ),
  //             ),
  //           );
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     print("❌ Error checking TTS API key: $e");
  //   }
  // }

  void _onGameStarted() {
    print("🎮 Game started - disabling microphone");
    // Stop any ongoing listening
    if (_isListening) {
      _speech.stop();
      _cancelSilenceTimer();
      setState(() => _isListening = false);
    }

    // Set a flag to prevent listening during games
    setState(() => _isMicDisabledDuringGame = true);
  }

  void _onGameEnded() {
    print("🎮 Game ended - re-enabling microphone");
    // Re-enable microphone
    setState(() => _isMicDisabledDuringGame = false);

    // Wait a moment before resuming listening
    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted &&
          !_isListening &&
          !_isThinking &&
          !_isSpeaking &&
          !_isMicDisabledDuringGame) {
        _startListening();
      }
    });
  }

  bool _isWaitingForAvatar = false;

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

  Future<void> _handleSilence() async {
    if (!mounted || _isStartingGame || _gameManager.isGameInProgress) return;
    setState(() => _isStartingGame = true);

    print("DEBUG: Silence detected for 15 seconds");

    // First stop the listening
    await _speech.stop();
    setState(() => _isListening = false);

    try {
      // Make sure any existing game is properly closed
      if (_gameManager.isGameInProgress) {
        print("DEBUG: Closing existing game before starting a new one");
        try {
          Navigator.of(context).popUntil((route) => route.isFirst);
          // Add delay to ensure UI updates
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print("DEBUG: Error closing existing game: $e");
        }
      }

      // Reset game state completely
      await _resetGame();

      // Ensure the game intro phrase is pre-cached before speaking
      print("DEBUG: Pre-caching game introduction phrase");
      await _ttsService.prefetchDynamic(["طيب تعالي نلعب لعبه"]);

      // Use a separate completer to ensure TTS fully completes
      final ttsCompleter = Completer<void>();

      // Use a manual approach for this specific TTS
      setState(() => _isSpeaking = true);
      _playAnimation(widget.avatarModel.talkingAnimation);

      print("DEBUG: Speaking game introduction");
      try {
        // Create a TTS completion handler specifically for game intro
        _ttsService.setCompletionHandler(() {
          print("DEBUG: Game intro TTS completed");
          if (mounted) {
            setState(() => _isSpeaking = false);
            _playAnimation(widget.avatarModel.idleAnimation);
            if (!ttsCompleter.isCompleted) {
              ttsCompleter.complete();
            }
          }
        });

        // Speak and wait for completion
        await _ttsService.speak("طيب تعالي نلعب لعبه");

        // Wait for completion handler to be called
        await ttsCompleter.future;

        // Ensure animation returns to idle
        setState(() => _isSpeaking = false);
        _playAnimation(widget.avatarModel.idleAnimation);

        // Restore original completion handler
        _ttsService.setCompletionHandler(_completionHandler!);
      } catch (e) {
        print("DEBUG: Error during game intro TTS: $e");
        // Ensure we reset state even on error
        setState(() => _isSpeaking = false);
        _playAnimation(widget.avatarModel.idleAnimation);
        _ttsService.setCompletionHandler(_completionHandler!);
      }

      // Longer safety delay
      await Future.delayed(const Duration(milliseconds: 1500));

      // Now it's safe to start the game - with additional precautions
      if (mounted && !_gameManager.isGameInProgress) {
        print("DEBUG: Starting game after confirmed TTS completion");

        // Set game start time
        _gameStartTime = DateTime.now();

        // Set game mode to true before starting game
        _ttsService.setGameMode(true);
        print("DEBUG: Game mode set to true before starting game");

        try {
          _gameManager.startGame(context, 1);
        } catch (e) {
          print("DEBUG: Error starting game: $e");
          setState(() => _isStartingGame = false);
        }
      } else {
        setState(() => _isStartingGame = false);
      }
    } catch (e) {
      print("DEBUG: Error in _handleSilence: $e");
      // Reset state if anything goes wrong
      setState(() => _isStartingGame = false);
      _ttsService.setCompletionHandler(_completionHandler!);
    }
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

// Fix for nullable function error in the _onModelLoaded method
// 5. Also modify the _onModelLoaded method to use the simplified speak for welcome

  // Update _onModelLoaded to handle loading screen and welcome message
  // Replace your _onModelLoaded method with this improved version
  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      print("✅ 3D Model loaded successfully");

      // Hide the waiting screen if it's still showing
      if (_showWaitingScreen) {
        setState(() => _showWaitingScreen = false);
      }

      // Start with greeting animation
      _playAnimation(widget.avatarModel.greetingAnimation);
      print("▶️ Playing greeting animation");

      // For the welcome message, add a delay to let the greeting animation play fully
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        // Set welcome message playing flag
        setState(() => _welcomeMessagePlaying = true);

        // Set welcome mode in TTS service to prevent waiting phrases
        try {
          _ttsService.setWelcomeMessageMode(true);
          print("✅ Welcome message mode set in TTS service");
        } catch (e) {
          // Fallback to setting game mode if welcome mode is not available
          print(
              "⚠️ setWelcomeMessageMode not available, using game mode instead");
          _ttsService.setGameMode(true);
        }

        // Ensure we're not listening during welcome
        if (_isListening) {
          _speech.stop();
          setState(() => _isListening = false);
        }

        print("🎤 Speaking welcome message with greeting animation");

        // Trim and validate welcome message
        final welcomeText = widget.initialResponse.trim().isNotEmpty
            ? widget.initialResponse
            : "مرحبا! كيف حالك اليوم؟";

        // Speak welcome message
        _simplifiedSpeak(welcomeText).then((_) {
          // Ensure welcome flag is cleared
          setState(() {
            _welcomeMessagePlaying = false;
          });

          // Reset welcome mode in TTS service
          try {
            _ttsService.setWelcomeMessageMode(false);
            print("✅ Welcome message mode cleared in TTS service");
          } catch (e) {
            // Fallback to resetting game mode if welcome mode is not available
            print(
                "⚠️ setWelcomeMessageMode not available, resetting game mode instead");
            _ttsService.setGameMode(false);
          }

          // Start listening after welcome message is complete
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted && !_isListening && !_isThinking && !_isSpeaking) {
              _startListening();
            }
          });
        });
      });
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

  void _forceResetThinkingState() {
    print("🔄 Forcing reset of thinking state");
    if (_isThinking) {
      setState(() {
        _isThinking = false;
        _isSpeaking = false;
      });

      // Reset to idle animation
      _playAnimation(widget.avatarModel.idleAnimation);

      // Try to stop any ongoing TTS
      _ttsService.stop();

      // Start listening
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted && !_isListening && !_isThinking && !_isSpeaking) {
          _startListening();
        }
      });
    }
  }

// Modify the method that processes user input to use the flag

// Also update _processUserInput to handle the welcome flag
  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    // Don't process input during welcome message
    if (_welcomeMessagePlaying) {
      print("⚠️ Ignoring user input during welcome message");
      return;
    }

    // Debug TTS state before processing
    _debugTtsState();

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

      // Debug TTS state after getting response
      _debugTtsState();

      // Use the simplified speak method instead
      await _simplifiedSpeak(aiResponse);
    } catch (e) {
      const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      await sessionController.addTherapistMessage(errorMsg);
      setState(() => _isThinking = false);
      await _simplifiedSpeak(errorMsg);
    }
  }
  // Future<void> _simulateSpeech(String text) async {
  //   print(
  //       "🔄 Simulating speech for: \"${text.substring(0, min(30, text.length))}...\"");

  //   // Show talking animation
  //   setState(() {
  //     _isThinking = false;
  //     _isSpeaking = true;
  //   });
  //   _playAnimation(widget.avatarModel.talkingAnimation);

  //   // Simulate speech duration based on text length
  //   final speechDuration = Duration(milliseconds: max(1000, 100 * text.length));
  //   await Future.delayed(speechDuration);

  //   // End speaking
  //   setState(() => _isSpeaking = false);
  //   _playAnimation(widget.avatarModel.idleAnimation);

  //   // Start listening again
  //   Future.delayed(Duration(milliseconds: 500), () {
  //     if (mounted && !_isListening && !_isThinking && !_isSpeaking) {
  //       _startListening();
  //     }
  //   });
  // }
  void _debugTtsState() {
    print("\n🔍 DEBUG TTS STATE");
    print("_isPlaying: ${_ttsService.isPlaying}");
    print("_isPreparingAudio: ${_ttsService.isPreparingAudio}");
    print("_welcomeMessagePlaying: $_welcomeMessagePlaying");
    print("_isThinking: $_isThinking");
    print("_isSpeaking: $_isSpeaking");
    print("_isListening: $_isListening");
    print("\n");
  }

  Future<void> _speak(String text, {bool useChildName = false}) async {
    try {
      // Stop any current speech
      if (_isSpeaking) {
        await _ttsService.stop();
        setState(() => _isSpeaking = false);
      }

      if (mounted) {
        try {
          setState(() => _isSpeaking = true);

          // Set a timeout to prevent getting stuck
          bool ttsCompleted = false;
          Timer(Duration(seconds: 8), () {
            if (!ttsCompleted && mounted) {
              print("⚠️ TTS timeout - forcing transition to next state");
              setState(() {
                _isThinking = false;
                _isSpeaking = false;
                // Clear welcome flag if it was set
                _welcomeMessagePlaying = false;
              });
              _playAnimation(widget.avatarModel.idleAnimation);

              // Only start listening if not in welcome message mode
              if (!_welcomeMessagePlaying) {
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted &&
                      !_isListening &&
                      !_isThinking &&
                      !_isSpeaking) {
                    _startListening();
                  }
                });
              }
            }
          });

          // Set handlers to coordinate animations
          _ttsService.setAudioReadyHandler(() {
            if (mounted) {
              print(
                  "🔊 Audio ready handler triggered, starting talking animation");
              setState(() {
                _isThinking = false;
                _isSpeaking = true;
              });
              _playAnimation(widget.avatarModel.talkingAnimation);
            }
          });

          _ttsService.setPreparingAudioHandler(() {
            if (mounted) {
              print(
                  "⏳ Preparing audio handler triggered, showing thinking animation");
              setState(() => _isThinking = true);
              _playAnimation(widget.avatarModel.thinkingAnimation);
            }
          });

          // Do not override the completion handler - it's set in initState
          // When we need custom completion for welcome, we temporarily override and restore it

          print(
              "🎤 Starting TTS for: \"${text.substring(0, min(30, text.length))}...\"");

          // Pass the child's name to the speak method if requested
          if (useChildName && _childName != null && _childName!.isNotEmpty) {
            print("🔍 Calling TTS with child name: $_childName");
            await _ttsService
                .speak(text, childName: _childName)
                .catchError((e) {
              print("❌ Error in TTS with child name: $e");
              ttsCompleted = true;
              return null;
            });
          } else {
            print("🔍 Calling TTS without child name");
            await _ttsService.speak(text).catchError((e) {
              print("❌ Error in TTS: $e");
              ttsCompleted = true;
              return null;
            });
          }

          ttsCompleted = true;
          print("✅ TTS speak call completed successfully");
        } catch (e) {
          print("❌ Error in TTS service: $e");
          setState(() {
            _isSpeaking = false;
            _isThinking = false;
          });
          _playAnimation(widget.avatarModel.idleAnimation);

          // Even on error, try to start listening if not in welcome mode
          if (mounted &&
              !_isListening &&
              !_isThinking &&
              !_welcomeMessagePlaying) {
            Future.delayed(Duration(milliseconds: 500), () {
              _startListening();
            });
          }
        }
      }
    } catch (e) {
      print("❌ Error in _speak: $e");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isThinking = false;
        });
        _playAnimation(widget.avatarModel.idleAnimation);
      }
    }
  }

  bool _useTtsApi = true;

// Add this method to toggle TTS API usage
  void _toggleTtsApi() {
    setState(() {
      _useTtsApi = !_useTtsApi;
      print("🔄 TTS API usage set to: $_useTtsApi");
    });

    // Show a message to the user
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_useTtsApi
          ? "TTS API enabled"
          : "TTS API disabled (using silent mode)"),
      duration: Duration(seconds: 2),
    ));
  }

  void _playAnimation(String animation) {
    print("🔍 DEBUG: _playAnimation called with: '$animation'");
    try {
      controller.playAnimation(animationName: animation);
      print("✅ Animation command sent: '$animation'");
    } catch (e) {
      print("❌ ERROR in _playAnimation: $e");
      // Check if we can get animation names to help debugging
      try {
        print("🔍 DEBUG: Attempting to list available animations");
        // If your controller has a method to get animation names, call it here
      } catch (e2) {
        print("⚠️ Cannot list animations: $e2");
      }
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

      // Create proper detection stats with all session data
      // This is the key fix to ensure aggregate stats are updated
      Map<String, dynamic> detectionStats = {
        'sessionDuration': timeSpent > 0 ? timeSpent : 0,
      };

      // Calculate message counts safely
      int childMessageCount = 0;
      int drMessageCount = 0;

      // Safely calculate message counts from conversation
      if (sessionController.state.conversation.isNotEmpty) {
        for (final msg in sessionController.state.conversation) {
          if (msg.containsKey('child')) {
            childMessageCount++;
          } else if (msg.containsKey('dr')) {
            drMessageCount++;
          }
        }
      }

      detectionStats['childMessages'] = childMessageCount;
      detectionStats['drMessages'] = drMessageCount;

      // Safely calculate total messages
      int totalMessages = childMessageCount + drMessageCount;
      detectionStats['totalMessages'] = totalMessages;

      // Calculate words per message (with safety check)
      int totalWords = 0;
      for (var msg in sessionController.state.conversation) {
        if (msg.containsKey('child') && msg['child'] != null) {
          totalWords += msg['child'].toString().split(' ').length;
        } else if (msg.containsKey('dr') && msg['dr'] != null) {
          totalWords += msg['dr'].toString().split(' ').length;
        }
      }

      detectionStats['wordsPerMessage'] =
          totalMessages > 0 ? (totalWords / totalMessages).round() : 0;

      // Game-related statistics
      detectionStats['gameStats'] = {
        'score': _totalScore,
        'levelsCompleted': _currentLevel,
        'correctAnswers': _correctAnswers,
        'wrongAnswers': _wrongAnswers,
        'timeSpent': timeSpent,
      };

      // Add focus/attention data from the summary if available
      if (summary != null) {
        detectionStats['focusData'] = summary;

        // If the summary contains focused percentage, include it directly
        if (summary.containsKey('focused_percentage')) {
          // Use null-safe conversion to num
          final focusedPercentageValue = summary['focused_percentage'];
          if (focusedPercentageValue is num) {
            detectionStats['focusedPercentage'] = focusedPercentageValue;
          }
        }
      }

      print("Ending session with detection stats: $detectionStats");

      // End session with complete stats
      if (mounted) {
        await sessionController.endSession(
          detectionStats, // Pass the proper detection stats instead of empty map
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

              // Safely get aggregateStats with null checks
              final Map<String, dynamic> defaultStats = {
                'totalSessions': 1,
                'averageSessionDuration': 0,
                'averageMessagesPerSession': 0
              };

              Map<String, dynamic> aggregateStats;
              if (widget.childData.containsKey('aggregateStats') &&
                  widget.childData['aggregateStats'] != null) {
                aggregateStats = Map<String, dynamic>.from(
                    widget.childData['aggregateStats']);
              } else {
                aggregateStats = defaultStats;
              }

              // Get session analyzer controller safely
              final sessionAnalyzer = Provider.of<SessionAnalyzerController>(
                  context,
                  listen: false);

              final recommendations =
                  await sessionAnalyzer.generateRecommendations(
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
    // Don't start listening if microphone is disabled during game
    if (_isMicDisabledDuringGame) {
      print(
          "⚠️ Microphone disabled during game - ignoring startListening request");
      return;
    }

    // Don't start listening if welcome message is playing
    if (_welcomeMessagePlaying) {
      print("⚠️ Not starting listening - welcome message playing");
      return;
    }

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
        print("🎤 Started listening with silence detection");

        await _speech.listen(
          onResult: (result) {
            // Reset silence timer on any partial result (even non-final)
            if (result.recognizedWords.isNotEmpty) {
              _startSilenceTimer();
              print("🎤 Speech detected, restarting silence timer");
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
        print("⚠️ Speech recognition not available");
      }
    } else {
      // If we're already listening and the button is pressed,
      // stop listening and cancel silence timer
      await _speech.stop();
      _cancelSilenceTimer();
      setState(() => _isListening = false);
      print("🎤 Manually stopped listening");
    }
  }

  Future<void> _initializeGame() async {
    try {
      print("🎮 DEBUG: Initializing game connections");

      if (!mounted) {
        print("🎮 DEBUG: Widget not mounted during game initialization");
        return;
      }

      // Reset state to prevent double-counting
      setState(() {
        _totalScore = 0;
        _correctAnswers = 0;
        _wrongAnswers = 0;
        _currentLevel = 1;
        _isGameInitialized = false; // Start with false
      });

      // Preload assets with error handling
      try {
        print("🎮 DEBUG: Preloading game assets");
        await _gameManager.preloadGameAssets(context);
        print("🎮 DEBUG: Game assets preloaded successfully");
      } catch (e) {
        print("🎮 DEBUG: Error preloading game assets: $e");
        // Continue even if preloading fails
      }

      // Clear out any previously registered callbacks first
      _gameManager.onGameCompleted = null;
      _gameManager.onGameFailed = null;
      _gameManager.onGameStatsUpdated = null;

      // Then register new callbacks with error handling
      _gameManager.onGameCompleted = (score, isLastLevel) {
        try {
          print(
              "🎮 DEBUG: onGameCompleted called with score=$score, isLastLevel=$isLastLevel");
          _ttsService.setGameMode(false);

          // Play clapping animation when a game is completed successfully
          _playAnimation(widget.avatarModel.clappingAnimation);

          // After clapping, show celebration message with error handling
          _ttsService.speak("برافو! أحسنت").catchError((e) {
            print("🎮 DEBUG: Error speaking celebration: $e");
          });

          // Return to idle animation after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isSpeaking && !_isListening && !_isThinking) {
              _playAnimation(widget.avatarModel.idleAnimation);
            }
          });

          // Update the state safely
          if (mounted) {
            setState(() {
              _totalScore = _gameManager.totalScore;
              _correctAnswers = _gameManager.correctAnswers;
              _wrongAnswers = _gameManager.wrongAnswers;
              if (!isLastLevel) _currentLevel = _gameManager.currentLevel;
            });
          }

          print(
              "🎮 DEBUG: After completion: _totalScore=$_totalScore, level=$_currentLevel");
        } catch (e, stack) {
          print("🎮 DEBUG: Error in onGameCompleted: $e");
          print("🎮 DEBUG: Stack trace: $stack");
        }
      };

      // Similar error handling for other callbacks
      _gameManager.onGameFailed = () {
        try {
          print("🎮 DEBUG: onGameFailed called");
          setState(() {
            _wrongAnswers = _gameManager.wrongAnswers;
          });
          print("🎮 DEBUG: After game failed: wrongAnswers=$_wrongAnswers");
        } catch (e) {
          print("🎮 DEBUG: Error in onGameFailed: $e");
        }
      };

      _gameManager.onGameStatsUpdated = (score, correct, wrong) {
        try {
          print(
              "🎮 DEBUG: onGameStatsUpdated called with score=$score, correct=$correct, wrong=$wrong");
          setState(() {
            _totalScore = score;
            _correctAnswers = correct;
            _wrongAnswers = wrong;
          });
          print("🎮 DEBUG: After stats update: _totalScore=$_totalScore");
        } catch (e) {
          print("🎮 DEBUG: Error in onGameStatsUpdated: $e");
        }
      };

      // Pre-cache common game-related TTS phrases
      try {
        await _ttsService.prefetchDynamic([
          "طيب تعالي نلعب لعبه",
          "برافو! أحسنت",
          "حاول تاني",
          "برافو! الإجابة صحيحة"
        ]);
        print("🎮 DEBUG: Game phrases pre-cached");
      } catch (e) {
        print("🎮 DEBUG: Error pre-caching game phrases: $e");
      }

      // Explicitly force a clean game state
      if (_gameManager.isGameInProgress) {
        print("🎮 DEBUG: Forcing game reset during initialization");
        try {
          _gameManager.resetGame();
        } catch (e) {
          print("🎮 DEBUG: Error resetting game: $e");
        }
      }

      // IMPORTANT: Set the initialization flag to true
      setState(() {
        _isGameInitialized = true;
      });
      print(
          "🎮 DEBUG: Game initialization complete (_isGameInitialized=$_isGameInitialized)");
    } catch (e) {
      print("🎮 DEBUG: Critical error in game initialization: $e");
      // Ensure initialization flag is set to false on error
      setState(() {
        _isGameInitialized = false;
      });
    }
  }

  Future<void> _resetGame() async {
    try {
      print("DEBUG: Starting game reset");

      // First, explicitly cancel any running timers
      if (_silenceTimer != null) {
        print("DEBUG: Canceling silence timer");
        _silenceTimer!.cancel();
        _isSilenceTimerActive = false;
      }

      // Next, reset the game manager state with proper error handling
      try {
        print("DEBUG: Resetting GameManager");
        _gameManager.resetGame();
      } catch (e) {
        print("ERROR: Failed to reset GameManager: $e");
        // Continue despite error
      }

      // Then wait to ensure the game manager has time to clean up
      await Future.delayed(const Duration(milliseconds: 300));

      // Then reset our local game state
      setState(() {
        _totalScore = 0;
        _correctAnswers = 0;
        _wrongAnswers = 0;
        _currentLevel = 1;
        _gameStartTime = DateTime.now();
        _isStartingGame = false; // Make sure this gets reset
      });

      print("DEBUG: Game state completely reset");
      return Future.value(); // Explicit return
    } catch (e) {
      print("DEBUG: Error in resetGame: $e");
      setState(() => _isStartingGame = false);
      // Ensure we return a completed future even with errors
      return Future.value();
    }
  }

  @override
  void dispose() {
    print("📱 SessionView dispose called");
    _silenceTimer?.cancel();
    controller.onModelLoaded.removeListener(_onModelLoaded);

    // IMPROVED: More thorough cleanup
    try {
      _speech.stop();
    } catch (e) {
      print("⚠️ Error stopping speech in dispose: $e");
    }

    try {
      _ttsService.stop();
    } catch (e) {
      print("⚠️ Error stopping TTS in dispose: $e");
    }

    _frameTimer?.cancel();
    _statsUpdateTimer?.cancel();

    try {
      _recorder.closeRecorder();
    } catch (e) {
      print("⚠️ Error closing recorder in dispose: $e");
    }

    try {
      _cameraController.dispose();
    } catch (e) {
      print("⚠️ Error disposing camera controller: $e");
    }

    try {
      _gameManager.dispose();
    } catch (e) {
      print("⚠️ Error disposing game manager: $e");
    }

    super.dispose();
  }

  Future<void> _prepareForStartingGame() async {
    print("🎮 DEBUG: Preparing to start game");

    // Stop any ongoing listening
    if (_isListening) {
      print("🎮 DEBUG: Stopping listening before game");
      await _speech.stop();
      _cancelSilenceTimer();
      setState(() => _isListening = false);
    }

    // Reset game state completely
    print("🎮 DEBUG: Resetting game state");

    // First ensure any existing game is closed
    if (_gameManager.isGameInProgress) {
      print("🎮 DEBUG: Force closing existing game");
      try {
        _gameManager.resetGame();
        // Wait a moment to ensure game is fully reset
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        print("🎮 DEBUG: Error resetting game: $e");
        // Continue despite error
      }
    }

    // Now reset the local game state
    setState(() {
      _totalScore = 0;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _currentLevel = 1;
      _gameStartTime = DateTime.now();
    });

    // IMPORTANT: Set game mode BEFORE any TTS operations
    print("🎮 DEBUG: Setting TTS to game mode");

    try {
      // First make absolutely sure we're not in welcome mode
      try {
        _ttsService.setWelcomeMessageMode(false);
      } catch (e) {
        print("🎮 DEBUG: setWelcomeMessageMode not available: $e");
      }

      // Then explicitly set game mode
      _ttsService.setGameMode(true);

      // Verify game mode is set - add a debug log to confirm
      print("🎮 DEBUG: Game mode status: ${_ttsService.isInGameMode}");
    } catch (e) {
      print("🎮 DEBUG: Error setting game mode: $e");
      // Continue despite error
    }

    // Add an extra validation step - stop any ongoing audio completely
    try {
      print("🎮 DEBUG: Stopping all audio before game announcement");
      await _ttsService.stopAllAudio();
      await Future.delayed(
          Duration(milliseconds: 200)); // Small delay for cleanup
    } catch (e) {
      print("🎮 DEBUG: Error stopping audio: $e");
    }

    // Announce game start using a Completer for better control
    print("🎮 DEBUG: Announcing game start");
    final speakCompleter = Completer<void>();

    // Set speaking state and animation
    setState(() => _isSpeaking = true);
    _playAnimation(widget.avatarModel.talkingAnimation);

    try {
      // Store original completion handler (safely)
      Function? originalCompletionHandler = _completionHandler;

      // Create a new temporary completion handler
      void tempCompletionHandler() {
        print("🎮 DEBUG: Game introduction speech completed");
        // Complete our local completer
        if (!speakCompleter.isCompleted) {
          speakCompleter.complete();
        }

        // Reset states
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
          _playAnimation(widget.avatarModel.idleAnimation);
        }
      }

      // Set our temporary handler
      _ttsService.setCompletionHandler(tempCompletionHandler);

      // IMPORTANT: Verify game mode is still set before speaking
      print("🎮 DEBUG: Verifying game mode before speaking announcement");
      try {
        // Check if we lost game mode somehow
        if (!_ttsService.isInGameMode) {
          print("🎮 DEBUG: Game mode was lost - resetting it");
          _ttsService.setGameMode(true);
        }
      } catch (e) {
        print("🎮 DEBUG: Error checking game mode: $e");
      }

      // Speak the game introduction
      print("🎮 DEBUG: Speaking game introduction");
      await _ttsService.speak("طيب تعالي نلعب لعبه");

      // Wait for speech completion with timeout
      await speakCompleter.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print("🎮 DEBUG: Speech timed out, continuing anyway");
          if (!speakCompleter.isCompleted) {
            speakCompleter.complete();
          }
        },
      );

      // Restore original completion handler (safely)
      if (originalCompletionHandler != null) {
        _ttsService.setCompletionHandler(originalCompletionHandler);
      } else {
        // If original was null, use an empty function to avoid null issues
        _ttsService.setCompletionHandler(() {
          print("🎮 DEBUG: Using default empty completion handler");
        });
      }
    } catch (e) {
      print("🎮 ERROR: Failed to announce game: $e");
      // Continue even if announcement fails
    }

    // Ensure speaking state is reset and animation returns to idle
    setState(() => _isSpeaking = false);
    _playAnimation(widget.avatarModel.idleAnimation);

    // Add a small delay to ensure UI updates
    await Future.delayed(Duration(milliseconds: 500));

    // IMPORTANT: Verify that game mode is STILL SET before starting the game
    print("🎮 DEBUG: Verifying game mode before starting game");
    try {
      if (!_ttsService.isInGameMode) {
        print("🎮 DEBUG: Game mode was lost - resetting it again");
        _ttsService.setGameMode(true);
      }
    } catch (e) {
      print("🎮 DEBUG: Error checking game mode: $e");
    }

    // Start the game with retry logic
    bool gameStarted = false;
    int retryCount = 0;
    Exception? lastError;

    while (!gameStarted && retryCount < 3) {
      try {
        print(
            "🎮 DEBUG: Starting game with GameManager (attempt ${retryCount + 1})");

        // Double-check game mode one last time
        _ttsService.setGameMode(true);

        _gameManager.startGame(context, 1);
        gameStarted = true;
        print("🎮 DEBUG: Game started successfully");
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print("🎮 ERROR: Failed to start game (attempt ${retryCount + 1}): $e");
        retryCount++;

        // Wait a moment before retrying
        if (retryCount < 3) {
          await Future.delayed(Duration(milliseconds: 300));
        }
      }
    }

    // If we couldn't start the game after 3 attempts, throw an error
    if (!gameStarted) {
      setState(() => _isStartingGame = false);
      throw lastError ??
          Exception("Failed to start game after multiple attempts");
    }
  }

// Add a helper method to reset the welcome message flag
  void _clearWelcomeFlag() {
    if (_welcomeMessagePlaying) {
      print("🎮 DEBUG: Clearing welcome message flag");
      setState(() {
        _welcomeMessagePlaying = false;
      });

      // Also try to reset the TTS service welcome mode if it exists
      try {
        if (_ttsService.setWelcomeMessageMode != null) {
          _ttsService.setWelcomeMessageMode(false);
        }
      } catch (e) {
        print("🎮 DEBUG: This TTS service doesn't have setWelcomeMessageMode");
        // Try fallback to game mode
        try {
          _ttsService.setGameMode(false);
        } catch (e) {
          print("🎮 DEBUG: Error resetting TTS modes: $e");
        }
      }
    }
  }

  Widget _buildControlButtons() {
    return LayoutBuilder(builder: (context, constraints) {
      // Determine if we're on a small screen
      final isSmallScreen = constraints.maxWidth < 360;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8.0 : 16.0, vertical: 8.0),
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

            if (_debugButtonPressed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _lastButtonDebugMessage,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            // Use Wrap for flexible button layout on smaller screens
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isSmallScreen ? 4.0 : 8.0,
              runSpacing: 8.0,
              children: [
                // Listen button
                _buildResponsiveButton(
                  onPressed: (_isListening ||
                          _isSpeaking ||
                          _isThinking ||
                          _isMicDisabledDuringGame ||
                          _welcomeMessagePlaying)
                      ? null
                      : _startListening,
                  icon: Icons.mic,
                  label: isSmallScreen ? "Listen" : "Start Listening",
                  color: Colors.blue,
                ),

                // Interrupt button
                _buildResponsiveButton(
                  onPressed: (_isListening || _isSpeaking || _isThinking)
                      ? () {
                          // Stop all current processes
                          if (_isListening) {
                            _speech.stop();
                            _cancelSilenceTimer();
                            setState(() => _isListening = false);
                          }
                          if (_isSpeaking) {
                            _ttsService.stop();
                            setState(() => _isSpeaking = false);
                          }
                          if (_isThinking) {
                            setState(() => _isThinking = false);
                          }
                          // Return to idle animation
                          _playAnimation(widget.avatarModel.idleAnimation);
                        }
                      : null,
                  icon: Icons.stop_circle,
                  label: isSmallScreen ? "Stop" : "Interrupt",
                  color: Colors.red,
                ),

                // Start game button - simplify the logic to make it more reliable
                _buildResponsiveButton(
                  onPressed: (!_isStartingGame &&
                          !_gameManager.isGameInProgress &&
                          !_isListening &&
                          !_isSpeaking &&
                          !_isThinking &&
                          !_welcomeMessagePlaying &&
                          _isGameInitialized)
                      ? () {
                          print("🎮 DEBUG: Start Game button pressed");
                          setState(() {
                            _debugButtonPressed = true;
                            _lastButtonDebugMessage = "Starting game...";
                            _isStartingGame = true;
                          });

                          // Use error handling when starting game
                          _prepareForStartingGame().then((_) {
                            if (mounted) {
                              setState(() {
                                _lastButtonDebugMessage =
                                    "Game started successfully!";
                              });
                            }
                          }).catchError((error) {
                            print("🎮 ERROR: Failed to prepare game: $error");
                            if (mounted) {
                              setState(() {
                                _isStartingGame = false;
                                _lastButtonDebugMessage =
                                    "Game start failed: $error";
                              });
                            }
                          });
                        }
                      : null,
                  icon: Icons.games,
                  label: isSmallScreen
                      ? (_isStartingGame ? "Starting..." : "Game")
                      : (_isStartingGame ? "Starting Game..." : "Start Game"),
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

// Helper method to create responsive buttons
  Widget _buildResponsiveButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        // Ensure text wrapping for very small devices
        textStyle: const TextStyle(
          fontSize: 14,
        ),
      ),
    );
  }

  // Add waiting screen widget
  Widget _buildWaitingScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              "Preparing Avatar...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
        body: _showWaitingScreen
            ? _buildWaitingScreen()
            : Stack(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                      // Use the new control buttons UI
                      _buildControlButtons(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
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
