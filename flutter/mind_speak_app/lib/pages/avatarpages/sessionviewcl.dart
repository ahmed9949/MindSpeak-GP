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
  Timer? _ttsStuckRecoveryTimer;

  late ChatGptTtsService _ttsService = ChatGptTtsService();
  DateTime? _gameStartTime;
  int _currentLevel = 1;
  // final int _maxLevel = 5;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  bool _isGameInitialized = false;
  String _currentAnimation = "idle";
  bool _animationLocked = false;
  DateTime _lastAnimationChange = DateTime.now();
  Timer? _stateCheckTimer;

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
    // Set up TTS handlers
    // Alternative if passing directly:
    _avatar = widget.avatar ?? Provider.of<AvatarModel>(context, listen: false);
    print(
        "DEBUG: Using avatar: ${_avatar.name} with model ${_avatar.modelPath}");
    print(
        "DEBUG: Avatar animations - idle: ${_avatar.idleAnimation}, talking: ${_avatar.talkingAnimation}");

    // Set up TTS handlers with specific animation states
    _ttsService.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _updateAnimationForSpeechState("mainEnd");
      }
    });
    _setupTtsWatchdog();

    _ttsService.setCancelHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _updateAnimationForSpeechState("mainEnd");
      }
    });

    _ttsService.setStartPlaybackHandler(() {
      if (mounted) {
        _updateAnimationForSpeechState("mainStart");
      }
    });

    // Add the new specific handlers
    _ttsService.setWaitingPhraseStartHandler(() {
      if (mounted) {
        _updateAnimationForSpeechState("waitingStart");
      }
    });

    _ttsService.setWaitingPhraseEndHandler(() {
      if (mounted) {
        _updateAnimationForSpeechState("waitingEnd");
      }
    });

    _ttsService.setMainSpeechStartHandler(() {
      if (mounted) {
        _updateAnimationForSpeechState("mainStart");
      }
    });
    // IMPORTANT: Create GameManager first before initializing games
    _gameManager = GameManager(ttsService: _ttsService);
    print("DEBUG: GameManager instance created");

    // Initialize session after creating GameManager
    _initializeSession();

    // Initialize game AFTER GameManager is created
    _initializeGame();

    // Start periodic stats update
    _startStatsUpdateTimer();
    _setupTtsStuckRecovery();

    _stateCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && (_isSpeaking || _ttsService.isPlaying)) {
        print("🕒 Periodic TTS state check:");
        _logTtsState();
      }
    });
    // Preload game assets for smoother performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameManager.preloadGameAssets(context);
      print("DEBUG: Game assets preloading started");
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

  Future<void> _resetTtsState() async {
    print("🔄 Resetting TTS state");

    // First, try to stop the TTS service
    await _ttsService.stop();

    // Force reset internal TTS state
    if (_ttsService is ChatGptTtsService) {
      (_ttsService as ChatGptTtsService).forceResetState();
    }

    // Reset UI state
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _animationLocked = false;
      });

      // Reset animation
      _playAnimation(_avatar.idleAnimation);
    }

    // Small delay to ensure stable state
    await Future.delayed(const Duration(milliseconds: 300));

    print("✅ TTS state reset complete");
  }

  void _updateAnimationForSpeechState(String state) {
    print("🎭 Speech state changed: $state");

    switch (state) {
      case "waitingStart":
        _lockAnimation(true);
        // Directly use the avatar's talking animation
        _playAnimation(_avatar.talkingAnimation);
        break;

      case "waitingEnd":
        // Don't unlock or change animation if main speech is about to start
        if (!_ttsService.isMainSpeechActive && !_ttsService.isPlaying) {
          print(
              "🎭 Waiting phrase ended, no main speech detected - returning to idle");
          _lockAnimation(false);
          _playAnimation(_avatar.idleAnimation);
        } else {
          print(
              "🎭 Waiting phrase ended, but main speech is active - keeping talk animation");
        }
        break;

      case "mainStart":
        _lockAnimation(true);
        // Directly use the avatar's talking animation
        _playAnimation(_avatar.talkingAnimation);
        break;

      case "mainEnd":
        // Immediate check - if nothing is playing, unlock animation right away
        if (!_ttsService.isPlaying && !_ttsService.isMainSpeechActive) {
          _lockAnimation(false);
          _playAnimation(_avatar.idleAnimation);

          // Also reset the speaking state if needed
          if (_isSpeaking) {
            print(
                "🎭 mainEnd: Forcing _isSpeaking to false as TTS is not active");
            setState(() => _isSpeaking = false);
          }
        } else {
          // Only short delay if actually playing
          print("🎭 mainEnd: Delaying animation unlock as TTS is still active");
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted &&
                !_ttsService.isPlaying &&
                !_ttsService.isMainSpeechActive) {
              _lockAnimation(false);
              _playAnimation(_avatar.idleAnimation);

              // Also reset the speaking state if needed
              if (_isSpeaking) {
                setState(() => _isSpeaking = false);
              }
            }
          });
        }
        break;
    }
  }

  void _onModelLoaded() {
    if (controller.onModelLoaded.value && mounted) {
      // Play initial idle animation - directly using the avatar's idle animation
      _playAnimation(_avatar.idleAnimation);

      // Log available animations for debugging
      print("🎭 Loaded avatar: ${_avatar.name} with animations:");
      print("   - idle: '${_avatar.idleAnimation}'");
      print("   - talking: '${_avatar.talkingAnimation}'");
      print("   - thinking: '${_avatar.thinkingAnimation}'");
      print("   - clapping: '${_avatar.clappingAnimation}'");
      print("   - greeting: '${_avatar.greetingAnimation}'");

      if (widget.initialResponse.isNotEmpty) {
        // Add a slight delay to ensure the UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // Don't use conversation mode for initial greeting
            _ttsService.setConversationMode(false);
            _speak(widget.initialResponse, isConversation: false);
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

  void _setupTtsStuckRecovery() {
    // Cancel any existing timer
    _ttsStuckRecoveryTimer?.cancel();

    // Set up new timer
    _ttsStuckRecoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isSpeaking) {
        bool actuallyPlaying =
            _ttsService.isPlaying || _ttsService.isMainSpeechActive;

        // Check if stuck - speaking state but no animation for a long time
        if (!actuallyPlaying) {
          print(
              "⚠️ TTS STUCK DETECTED: UI speaking ($_currentAnimation) but TTS not active");
          _logTtsState();

          // Only attempt recovery if we've been in this state for a while
          final stuckDuration = DateTime.now().difference(_lastAnimationChange);

          if (stuckDuration.inSeconds > 2) {
            print(
                "⚠️ Attempting recovery from stuck TTS (stuck for ${stuckDuration.inSeconds}s)");

            // Use our new comprehensive reset method
            _resetTtsState();
          }
        }
      }
    });
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

  Future<void> _speak(String text, {bool isConversation = false}) async {
    if (mounted) {
      try {
        print("🎤 Starting speak method with isConversation=$isConversation");
        print(
            "🎤 Current state: _isSpeaking=$_isSpeaking, ttsService.isPlaying=${_ttsService.isPlaying}");

        // Ensure we're not already in an inconsistent state
        if (_ttsService.isPlaying) {
          print("⚠️ TTS is already playing, stopping first");
          await _ttsService.stop();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        setState(() => _isSpeaking = true);

        // Directly use the avatar's talking animation
        _playAnimation(_avatar.talkingAnimation);
        _lockAnimation(true);

        debugPrint(
            'Starting TTS for text: "${text.substring(0, min(30, text.length))}..."');

        // Set up a safety timer in case TTS gets stuck
        final safetyTimer = Timer(const Duration(seconds: 10), () {
          if (mounted && _isSpeaking) {
            print("⚠️ Safety timer triggered - TTS may be stuck");
            _logTtsState();

            if (!_ttsService.isPlaying && !_ttsService.isMainSpeechActive) {
              print("⚠️ TTS appears stuck, performing recovery");
              _ttsService.stop().then((_) {
                if (mounted) {
                  setState(() => _isSpeaking = false);
                  _updateAnimationForSpeechState("mainEnd");
                }
              });
            }
          }
        });

        try {
          await _ttsService.speak(text, isConversation: isConversation);
          debugPrint('TTS speak method completed');
        } finally {
          safetyTimer.cancel(); // Clean up timer regardless of outcome
        }
      } catch (e) {
        debugPrint('❌ Error in TTS service: $e');
        setState(() => _isSpeaking = false);
        _updateAnimationForSpeechState("mainEnd");
      }
    } else {
      debugPrint('⚠️ Widget not mounted, skipping TTS');
    }
  }

  void _setupTtsWatchdog() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Only check when we think we're speaking
      if (_isSpeaking) {
        bool actuallyPlaying =
            _ttsService.isPlaying || _ttsService.isMainSpeechActive;

        if (!actuallyPlaying) {
          // Give a small grace period before taking action
          if (_lastAnimationChange.difference(DateTime.now()).inSeconds.abs() >
              3) {
            print("🚨 WATCHDOG: TTS state mismatch detected:");
            _logTtsState();
            print(
                "🚨 WATCHDOG: Animation locked: $_animationLocked, Last change: $_lastAnimationChange");

            // Take recovery action
            print("🔄 WATCHDOG: Performing state recovery");
            _ttsService.stop().then((_) {
              if (mounted) {
                setState(() => _isSpeaking = false);
                _lockAnimation(false);
                _playAnimation(_avatar.idleAnimation);
              }
            });
          }
        }
      }
    });
  }

  Future<void> _processUserInput(String text) async {
    if (text.isEmpty) return;

    print("🗣️ Processing user input: \"$text\"");
    _logTtsState();

    // Ensure we're in a clean state before starting
    if (_isSpeaking || _ttsService.isPlaying) {
      print("⚠️ Already speaking, resetting state first");
      await _resetTtsState(); // Use our new reset method
    }

    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    await sessionController.addChildMessage(text);
    await _recordAndAnalyzeVoice(text);

    try {
      // Enable conversation mode for TTS
      _ttsService.setConversationMode(true);

      final prompt =
          "Child's message: $text\n\nRespond in Egyptian Arabic. Be encouraging, short, and positive.";
      print(
          "💬 Sending message to AI: \"${prompt.substring(0, min(50, prompt.length))}...\"");

      final aiResponse =
          await _chatModel.sendMessage(prompt, childData: widget.childData);
      print(
          "💬 Received AI response: \"${aiResponse.substring(0, min(50, aiResponse.length))}...\"");

      await sessionController.addTherapistMessage(aiResponse);

      print("🎤 Starting TTS for AI response");
      _logTtsState();

      // Set speaking state
      setState(() => _isSpeaking = true);

      // Use the conversation flag when speaking
      try {
        await _speak(aiResponse, isConversation: true);
        print("✅ _speak method completed successfully");
      } catch (e) {
        print("❌ Error in _speak: $e");

        // Recovery attempt
        if (mounted) {
          print("🔄 Attempting recovery with simplified approach");
          await _resetTtsState();

          // Try one more time with conversation mode off
          setState(() => _isSpeaking = true);
          _ttsService.setConversationMode(false);
          await _speak(aiResponse, isConversation: false);
        }
      }

      // Add verification timeout to catch stuck states
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isSpeaking) {
          bool actuallyPlaying =
              _ttsService.isPlaying || _ttsService.isMainSpeechActive;
          if (!actuallyPlaying) {
            print(
                "⚠️ Verification check failed - TTS not active but UI thinks it's speaking");
            _resetTtsState();
          }
        }
      });

      print("🎤 _processUserInput method completed");
      _logTtsState();
    } catch (e) {
      print("❌ Error in _processUserInput: $e");
      const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      await sessionController.addTherapistMessage(errorMsg);

      // Reset state before trying to speak the error
      await _resetTtsState();

      setState(() => _isSpeaking = true);
      await _speak(errorMsg, isConversation: false);
    }
  }

  void _logTtsState() {
    print("🔍 TTS STATE DIAGNOSTIC:");
    print("  _isSpeaking: $_isSpeaking");
    print("  _ttsService.isPlaying: ${_ttsService.isPlaying}");
    print(
        "  _ttsService.isMainSpeechActive: ${_ttsService.isMainSpeechActive}");
    print("  _currentAnimation: $_currentAnimation");
    print("  _animationLocked: $_animationLocked");
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

  void _lockAnimation(bool lock) {
    // Only use animation locking during speech
    if (_isSpeaking) {
      _animationLocked = lock;
      print("🔒 Animation ${lock ? 'locked' : 'unlocked'} during speech");
    } else {
      _animationLocked = false;
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
      _ttsService.setConversationMode(false);

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
      await _speak(goodbye, isConversation: false);

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
    _stateCheckTimer?.cancel();
    _ttsStuckRecoveryTimer?.cancel();

    print("DEBUG: SessionView dispose called");
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
                      src: _avatar.modelPath,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "Facial: ${_facialEmotion ?? 'Unknown'}",
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black),
                          ),
                          Text(
                            "Voice: ${_voiceEmotion ?? 'Not analyzed'}",
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black),
                          ),
                        ],
                      ),
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
                ElevatedButton(
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
                    backgroundColor: isDark ? Colors.grey[800] : primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isListening ? "Recording..." : "Start Talking"),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Reset game state before starting a new game
                        _resetGame();

                        // Start a fresh game from level 1
                        print("DEBUG: Starting game from level 1");
                        _gameManager.startGame(context, 1);
                      },
                      icon: const Icon(Icons.games),
                      label: const Text("Play Game 🎮"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.grey[800] : primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSpeaking
                          ? () async {
                              await _ttsService.stop();
                              setState(() => _isSpeaking = false);
                              _playAnimation(_avatar.idleAnimation);
                            }
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text("Stop TTS"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.grey[800] : primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
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
                // Debug reset button for testing
                ElevatedButton(
                  onPressed: _resetGame,
                  child: const Text("Reset Score"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
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



// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_3d_controller/flutter_3d_controller.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:image/image.dart' as img;
// import 'package:mind_speak_app/controllers/detectioncontroller.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';
// import 'package:camera/camera.dart';

// import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
// import 'package:mind_speak_app/service/avatarservice/openai.dart';
// import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';

// class SessionView extends StatefulWidget {
//   final String initialPrompt;
//   final String initialResponse;
//   final Map<String, dynamic> childData;

//   const SessionView({
//     super.key,
//     required this.initialPrompt,
//     required this.initialResponse,
//     required this.childData,
//   });

//   @override
//   State<SessionView> createState() => _SessionViewState();
// }

// class _SessionViewState extends State<SessionView> {
//   final GlobalKey _avatarKey = GlobalKey();
//   final Flutter3DController controller = Flutter3DController();
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   final ChatGptTtsService _ttsService = ChatGptTtsService();

//   late AiService _aiService;
//   late DetectionController _detectionController;
//   late ChatGptModel _chatModel;
//   late String? _sessionId;

//   // Camera variables
//   late CameraController _cameraController;
//   bool _isCameraInitialized = false;

//   Timer? _frameTimer;
//   bool _isRecording = false;
//   bool _isListening = false;
//   bool _isSpeaking = false;
//   String? _childName;
//   String? _voiceEmotion;
//   String? _facialEmotion;

//   @override
//   void initState() {
//     super.initState();
//     _initializeSession();
//   }

//   Future<void> ensureCameraPermission() async {
//     var status = await Permission.camera.status;
//     if (!status.isGranted) {
//       status = await Permission.camera.request();
//       if (!status.isGranted) {
//         throw Exception("Camera permission denied");
//       }
//     }
//   }

//   Future<void> _initializeSession() async {
//     try {
//       await ensureCameraPermission();
//       _chatModel = Provider.of<ChatGptModel>(context, listen: false);
//       _aiService = AiService();
//       _detectionController = DetectionController();
//       _sessionId = Provider.of<SessionController>(context, listen: false)
//           .state
//           .sessionId;
//       _childName = widget.childData['name'];
//       controller.onModelLoaded.addListener(_onModelLoaded);
//       await _initializeCamera();
//       await _initSpeech();
//       await _initRecorder();
//       _startFrameTimer();
//     } catch (e) {
//       debugPrint('❌ Permission error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Camera permission is required')),
//       );
//     }
//   }

//   Future<void> _initializeCamera() async {
//     try {
//       final cameras = await availableCameras();
//       CameraDescription? frontCamera;
//       for (var camera in cameras) {
//         if (camera.lensDirection == CameraLensDirection.front) {
//           frontCamera = camera;
//           break;
//         }
//       }

//       _cameraController = CameraController(
//         frontCamera ?? cameras.first,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: Platform.isAndroid
//             ? ImageFormatGroup.yuv420
//             : ImageFormatGroup.bgra8888,
//       );

//       await _cameraController.initialize();
//       setState(() => _isCameraInitialized = true);
//       debugPrint('✅ Camera initialized successfully');
//     } catch (e) {
//       debugPrint('❌ Error initializing camera: $e');
//     }
//   }

//   void _onModelLoaded() {
//     if (controller.onModelLoaded.value && mounted) {
//       _playAnimation("idle.001");
//       if (widget.initialResponse.isNotEmpty) {
//         _speak(widget.initialResponse);
//       }
//     }
//   }

//   Future<void> _initSpeech() async {
//     await _speech.initialize(
//       onStatus: (status) {
//         if (status == 'notListening' || status == 'done') {
//           setState(() => _isListening = false);
//           _playAnimation("idle.001");
//         }
//       },
//       onError: (error) {
//         setState(() => _isListening = false);
//         _playAnimation("idle.001");
//       },
//     );
//   }

//   Future<void> _initRecorder() async {
//     await _recorder.openRecorder();
//   }

//   void _startFrameTimer() {
//     _frameTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
//       await _captureAndAnalyzeFrame();
//     });
//   }

//   Future<void> _captureAndAnalyzeFrame() async {
//     try {
//       if (!_isCameraInitialized || !_cameraController.value.isInitialized) {
//         debugPrint('⚠️ Camera not initialized, skipping frame capture');
//         return;
//       }

//       // Capture frame from camera
//       final XFile imageFile = await _cameraController.takePicture();

//       // Analyze the captured frame
//       await _analyzeAllFrameData(File(imageFile.path));
//     } catch (e) {
//       debugPrint('❌ Error capturing frame: $e');
//     }
//   }

//   Future<void> _analyzeAllFrameData(File frame) async {
//     try {
//       final detectionData = <String, dynamic>{
//         'timestamp': DateTime.now().toIso8601String(),
//       };

//       // 👁️ 1. Eye Gaze Analysis (using base64)
//       try {
//         List<int> imageBytes = await frame.readAsBytes();
//         String base64Image = base64Encode(imageBytes);

//         // Analyze gaze using base64 image
//         final gazeResult = await _aiService.analyzeGazeFromBase64(base64Image);
//         if (gazeResult != null) {
//           detectionData['gaze'] = {
//             'status': gazeResult['focus_status'] ?? 'Unknown',
//             'focused_percentage': gazeResult['focused_percentage'] ?? 0,
//             'not_focused_percentage': gazeResult['not_focused_percentage'] ?? 0,
//           };
//         }
//       } catch (e) {
//         debugPrint('❌ Error in gaze detection: $e');
//       }

//       // 🔍 2. Behavior Detection
//       try {
//         final behaviorResult = await _aiService.analyzeBehavior(frame);
//         if (behaviorResult != null && behaviorResult['behavior'] != null) {
//           detectionData['behavior'] = behaviorResult['behavior'];
//         }
//       } catch (e) {
//         debugPrint('❌ Error in behavior detection: $e');
//       }

//       // 😊 3. Facial Emotion Detection
//       try {
//         final emotionResult = await _aiService.analyzeEmotionFromImage(frame);
//         if (emotionResult != null && emotionResult['emotion'] != null) {
//           detectionData['emotion'] = emotionResult['emotion'];
//           setState(() => _facialEmotion = emotionResult['emotion']);
//         }
//       } catch (e) {
//         debugPrint('❌ Error in emotion detection: $e');
//       }

//       // Log detection data
//       debugPrint('Detection data: ${jsonEncode(detectionData)}');

//       // ✅ Save to Firestore
//       if (_sessionId != null) {
//         await _detectionController.addDetection(
//           sessionId: _sessionId!,
//           detectionData: detectionData,
//         );
//       } else {
//         debugPrint('❌ Cannot save detection: No session ID available');
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error in _analyzeAllFrameData: $e');
//       debugPrint('Stack trace: $stackTrace');
//     }
//   }

//   Future<void> _recordAndAnalyzeVoice(String sttText) async {
//     if (_isRecording) return;

//     final tempDir = await getTemporaryDirectory();
//     final filePath =
//         '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

//     try {
//       debugPrint('🎙️ Starting voice recording...');
//       setState(() => _isRecording = true);

//       await _recorder.startRecorder(toFile: filePath);
//       // Record for a few seconds to capture enough audio for analysis
//       await Future.delayed(const Duration(seconds: 3));
//       await _recorder.stopRecorder();

//       final fileStats = await File(filePath).stat();
//       debugPrint('🎙️ Voice recording completed: ${fileStats.size} bytes');

//       // Analyze the voice recording
//       final result = await _aiService.analyzeEmotionFromVoice(File(filePath));

//       if (result != null && mounted) {
//         debugPrint('🎧 Voice emotion detected: ${result['emotion']}');
//         setState(() => _voiceEmotion = result['emotion']);

//         // Save voice emotion detection to Firestore
//         if (_sessionId != null) {
//           await _detectionController.addDetection(
//             sessionId: _sessionId!,
//             detectionData: {
//               'timestamp': DateTime.now().toIso8601String(),
//               'voiceEmotion': result['emotion'],
//               'speechText': sttText,
//             },
//           );
//         }
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ Voice analysis error: $e');
//       debugPrint('Stack trace: $stackTrace');
//     } finally {
//       setState(() => _isRecording = false);

//       // Clean up the temporary file
//       try {
//         if (await File(filePath).exists()) {
//           await File(filePath).delete();
//         }
//       } catch (e) {
//         debugPrint('Error cleaning up audio file: $e');
//       }
//     }
//   }

//   Future<void> _processUserInput(String text) async {
//     if (text.isEmpty) return;
//     final sessionController =
//         Provider.of<SessionController>(context, listen: false);
//     await sessionController.addChildMessage(text);
//     await _recordAndAnalyzeVoice(text);

//     try {
//       final prompt =
//           "Child's message: $text\n\nRespond in Egyptian Arabic. Be encouraging, short, and positive.";
//       final aiResponse =
//           await _chatModel.sendMessage(prompt, childData: widget.childData);
//       await sessionController.addTherapistMessage(aiResponse);
//       await _speak(aiResponse);
//     } catch (e) {
//       const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
//       await sessionController.addTherapistMessage(errorMsg);
//       await _speak(errorMsg);
//     }
//   }

//   Future<void> _speak(String text) async {
//     if (!_isSpeaking && mounted) {
//       setState(() => _isSpeaking = true);
//       _playAnimation("newtalk");
//       await _ttsService.speak(text);
//       setState(() => _isSpeaking = false);
//       _playAnimation("idle.001");
//     }
//   }

//   void _playAnimation(String animation) {
//     try {
//       controller.playAnimation(animationName: animation);
//     } catch (e) {
//       debugPrint('Animation error: $e');
//     }
//   }

//   Future<void> _endSession() async {
//     final sessionController =
//         Provider.of<SessionController>(context, listen: false);
//     if (_isListening) await _speech.stop();
//     if (_isSpeaking) await _ttsService.stop();
//     final goodbye =
//         _childName != null ? "الى اللقاء $_childName" : "الى اللقاء";
//     await sessionController.addTherapistMessage(goodbye);
//     await _speak(goodbye);

//     // Fetch detection summary from Flask
//     final summary = await _aiService.endConversationAndFetchSummary();
//     if (summary != null) {
//       await _detectionController.addDetection(
//         sessionId: _sessionId!,
//         detectionData: summary,
//       );
//     }

//     // End session and get stats
//     final stats = await sessionController.endSession({});

//     // Generate recommendations
//     final sessionData = await sessionController.getSessionById(_sessionId!);
//     if (sessionData != null) {
//       final childId = sessionData.childId;
//       final allSessions = await sessionController.getSessionsForChild(childId);
//       final aggregateStats = widget.childData['aggregateStats'] ??
//           {
//             'totalSessions': 1,
//             'averageSessionDuration': 0,
//             'averageMessagesPerSession': 0
//           };

//       final recommendations =
//           await Provider.of<SessionAnalyzerController>(context, listen: false)
//               .generateRecommendations(
//         childData: widget.childData,
//         recentSessions: allSessions,
//         aggregateStats: aggregateStats,
//       );

//       await sessionController.generateRecommendations(
//         childId,
//         recommendations['parents'] ?? '',
//         recommendations['therapists'] ?? '',
//       );
//     }

//     // Navigate out after save
//     if (mounted) Navigator.pop(context);
//   }

//   @override
//   void dispose() {
//     controller.onModelLoaded.removeListener(_onModelLoaded);
//     _speech.stop();
//     _ttsService.stop();
//     _frameTimer?.cancel();
//     _recorder.closeRecorder();
//     _cameraController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Therapy Session")),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Expanded(
//                 flex: 3,
//                 child: RepaintBoundary(
//                   key: _avatarKey,
//                   child: Flutter3DViewer(
//                     src: 'assets/models/banotamixamonewtalk.glb',
//                     controller: controller,
//                     activeGestureInterceptor: true,
//                   ),
//                 ),
//               ),

//               // Optional: Emotion status display
//               Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     Text("Facial: ${_facialEmotion ?? 'Unknown'}"),
//                     Text("Voice: ${_voiceEmotion ?? 'Not analyzed'}"),
//                   ],
//                 ),
//               ),

//               ElevatedButton(
//                 onPressed: () async {
//                   if (!_isListening) {
//                     final available = await _speech.initialize();
//                     if (available) {
//                       setState(() => _isListening = true);
//                       _playAnimation("idle.001");
//                       await _speech.listen(
//                         onResult: (result) {
//                           if (result.finalResult) {
//                             _processUserInput(result.recognizedWords);
//                             setState(() => _isListening = false);
//                           }
//                         },
//                         listenMode: stt.ListenMode.dictation,
//                         partialResults: true,
//                         localeId: 'ar-EG',
//                       );
//                     }
//                   } else {
//                     await _speech.stop();
//                     setState(() => _isListening = false);
//                   }
//                 },
//                 child: Text(_isListening ? "Recording..." : "Start Talking"),
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton.icon(
//                     onPressed: _isSpeaking
//                         ? () async {
//                             await _ttsService.stop();
//                             setState(() => _isSpeaking = false);
//                             _playAnimation("idle.001");
//                           }
//                         : null,
//                     icon: const Icon(Icons.stop),
//                     label: const Text("Stop TTS"),
//                   ),
//                   ElevatedButton.icon(
//                     onPressed: _endSession,
//                     icon: const Icon(Icons.call_end),
//                     label: const Text("End Call"),
//                     style:
//                         ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   )
//                 ],
//               )
//             ],
//           ),

//           // Hidden camera preview (for capturing frames)
//           Positioned(
//             bottom: 0,
//             right: 0,
//             child: Opacity(
//               opacity: 0.0, // Make invisible
//               child: SizedBox(
//                 width: 1, // Minimal size
//                 height: 1,
//                 child: _isCameraInitialized
//                     ? CameraPreview(_cameraController)
//                     : Container(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }