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
  final GlobalKey _avatarKey = GlobalKey();
  final Flutter3DController controller = Flutter3DController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late GameManager _gameManager;

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
  String? _childName;
  String? _voiceEmotion;
  String? _facialEmotion;

  final ChatGptTtsService _ttsService = ChatGptTtsService();
  DateTime? _gameStartTime;
  int _currentLevel = 1;
  // final int _maxLevel = 5;
  int _totalScore = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  @override
  void initState() {
    super.initState();
    _initializeSession();

    // Initialize TTS with common phrases
    _ttsService.initialize().then((_) {
      print("TTS service ready with preloaded phrases");
    });
    // Setup the game manager
    _gameManager = GameManager(ttsService: _ttsService);

    // Preload game assets for smoother performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameManager.preloadGameAssets(context);
    });
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
      _playAnimation("idle.001");
      debugPrint(
          '3D Model loaded, initial response: "${widget.initialResponse}"');

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
          _playAnimation("idle.001");
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        _playAnimation("idle.001");
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
              _playAnimation("idle.001"); // Play focused animation
            } else {
              // Optional: Play a subtle "attention" animation if not focused
              // But don't interrupt speaking animation
              if (!_isSpeaking) {
                _playAnimation("idle.001");
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
    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    await sessionController.addChildMessage(text);
    await _recordAndAnalyzeVoice(text);

    try {
      final prompt =
          "Child's message: $text\n\nRespond in Egyptian Arabic. Be encouraging, short, and positive.";
      final aiResponse =
          await _chatModel.sendMessage(prompt, childData: widget.childData);
      await sessionController.addTherapistMessage(aiResponse);
      await _speak(aiResponse);
    } catch (e) {
      const errorMsg = "عذراً، حدث خطأ أثناء المعالجة.";
      await sessionController.addTherapistMessage(errorMsg);
      await _speak(errorMsg);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isSpeaking && mounted) {
      try {
        setState(() => _isSpeaking = true);
        _playAnimation("newtalk");
        debugPrint(
            'Starting TTS for text: "${text.substring(0, min(30, text.length))}..."');
        await _ttsService.speak(text);
        debugPrint('TTS completed successfully');
      } catch (e) {
        debugPrint('❌ Error in TTS service: $e');
        // Don't rethrow - we want to continue with animation cleanup
      } finally {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _playAnimation("idle.001");
        }
      }
    }
  }

  void _playAnimation(String animation) {
    try {
      controller.playAnimation(animationName: animation);
    } catch (e) {
      debugPrint('Animation error: $e');
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

  Future<void> _showRandomMiniGame() async {
    _gameStartTime = DateTime.now();

    // Set up listeners for game results with optimized callback handling
    _gameManager.onGameCompleted = (int score, bool isLastLevel) {
      // Use setState with minimal updates
      setState(() {
        _totalScore += score;
        _correctAnswers++;
        if (!isLastLevel) {
          _currentLevel++;
        }
      });

      // Show level completion animation with frame sync
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _gameManager.showLevelCompletionAnimation(isLastLevel);
      });
    };

    _gameManager.onGameFailed = () {
      setState(() {
        _wrongAnswers++;
      });
    };

    // Ensure any pending game is completed first
    await Future.delayed(Duration.zero);

    // Start the game with the current level
    if (mounted) {
      _gameManager.startGame(context, _currentLevel);
    }
  }
  @override
  void dispose() {
    controller.onModelLoaded.removeListener(_onModelLoaded);
    _speech.stop();
    _ttsService.stop();
    _frameTimer?.cancel();
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
                      src: 'assets/models/banotamixamonewtalk.glb',
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
                        _playAnimation("idle.001");
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
                      onPressed: _showRandomMiniGame,
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
                              _playAnimation("idle.001");
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
