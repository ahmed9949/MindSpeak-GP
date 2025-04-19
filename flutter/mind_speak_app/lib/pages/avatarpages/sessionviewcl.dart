import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:lottie/lottie.dart';
import 'package:mind_speak_app/controllers/detectioncontroller.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/components/game_card.dart';

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
  final ChatGptTtsService _ttsService = ChatGptTtsService();

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

  int _totalScore = 0;

  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  late DateTime _gameStartTime;

  @override
  void initState() {
    super.initState();
    _initializeSession();
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
    final sessionController =
        Provider.of<SessionController>(context, listen: false);
    if (_isListening) await _speech.stop();
    if (_isSpeaking) await _ttsService.stop();
    final goodbye =
        _childName != null ? "الى اللقاء $_childName" : "الى اللقاء";
    await sessionController.addTherapistMessage(goodbye);
    await _speak(goodbye);

    // Fetch detection summary from Flask
    final summary = await _aiService.endConversationAndFetchSummary();
    if (summary != null) {
      await _detectionController.addDetection(
        sessionId: _sessionId!,
        detectionData: summary,
      );
    }
    print("👉 Ending session...");
    // End session and get stats
    final stats = await sessionController.endSession(
      {}, // detection stats
      totalScore: _totalScore,
      levelsCompleted: _currentLevel,
      correctAnswers: _correctAnswers,
      wrongAnswers: _wrongAnswers,
      timeSpent: DateTime.now().difference(_gameStartTime).inSeconds,
    );
    print("✅ Session ended and stats saved!");

    // Generate recommendations
    final sessionData = await sessionController.getSessionById(_sessionId!);
    if (sessionData != null) {
      final childId = sessionData.childId;
      final allSessions = await sessionController.getSessionsForChild(childId);
      final aggregateStats = widget.childData['aggregateStats'] ??
          {
            'totalSessions': 1,
            'averageSessionDuration': 0,
            'averageMessagesPerSession': 0
          };

      final recommendations =
          await Provider.of<SessionAnalyzerController>(context, listen: false)
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

    // Navigate out after save
    if (mounted) Navigator.pop(context);
  }

  int _currentLevel = 1;
  final int _maxLevel = 5;
  List<Map<String, dynamic>>? _cachedImages;
  String? _cachedCategory;
  String? _cachedType;
  final AudioPlayer _levelUpPlayer = AudioPlayer(); // Reuse this


Future<void> _showRandomMiniGame() async {
  final imageService = GameImageService();
  _gameStartTime = DateTime.now();

  // 👉 Level 5: Math using fingers
  if (_currentLevel == 5) {
    final rand = Random();
    final num1 = rand.nextInt(6);
    final num2 = rand.nextInt(6);
    final operator = ['+', '-', '×'][rand.nextInt(3)];

    int answer;
    switch (operator) {
      case '+':
        answer = num1 + num2;
        break;
      case '-':
        answer = num1 - num2;
        break;
      case '×':
        answer = num1 * num2;
        break;
      default:
        answer = 0;
    }

    Set<int> options = {answer};
    while (options.length < 3) {
      options.add(answer + rand.nextInt(5) - 2);
    }
    final optionList = options.toList()..shuffle();

    final url1 = await imageService.getRandomImage("Fingers", "$num1");
    final url2 = await imageService.getRandomImage("Fingers", "$num2");

    if (url1 == null || url2 == null) return;

    await _ttsService.speak("ما ناتج $num1 $operator $num2؟");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final themeProvider = Provider.of<ThemeProvider>(bottomSheetContext);
        final colorProvider = Provider.of<ColorProvider>(bottomSheetContext);
        final primaryColor = colorProvider.primaryColor;
        final isDark = themeProvider.isDarkMode;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "$num1 $operator $num2 = ?",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(url1, height: 100),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(operator, style: const TextStyle(fontSize: 28)),
                    ),
                    Image.network(url2, height: 100),
                  ],
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: optionList.map((opt) {
                    return InkWell(
                      onTap: () async {
                        if (opt == answer) {
                          await _ttsService.speak("برافو! الإجابة صحيحة");
                          setState(() {
                            _totalScore++;
                            _correctAnswers++;
                          });
                          Navigator.pop(context);
                        } else {
                          await _ttsService.speak("لا، حاول مرة أخرى");
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          "$opt",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    return;
  }

  // 🔁 Original logic for levels 1–4
  if (_cachedImages == null || _cachedImages!.isEmpty) {
    final categories = ['Animals', 'Fruits', 'Body_Parts'];
    final selectedCategory = categories[Random().nextInt(categories.length)];
    final types = await imageService.getTypesInCategory(selectedCategory);

    if (types.length < _currentLevel + 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough types for this level.")),
        );
      }
      return;
    }

    final selectedType = types[Random().nextInt(types.length)];
    final imageData = await imageService.getLabeledImages(
      category: selectedCategory,
      correctType: selectedType,
      count: _currentLevel + 1,
    );

    if (imageData.length < _currentLevel + 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough images for this level.")),
        );
      }
      return;
    }

    _cachedImages = imageData;
    _cachedCategory = selectedCategory;
    _cachedType = selectedType;
  }

  // ➕ Show MiniGameCard (levels 1–4)
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          controller: scrollController,
          child: MiniGameCard(
            category: _cachedCategory!,
            type: _cachedType!,
            level: _currentLevel + 1,
            ttsService: _ttsService,
            images: _cachedImages!,
            onCorrect: (points) async {
              _totalScore += points;
              _correctAnswers++;
              final isLastLevel = _currentLevel >= _maxLevel;

              setState(() {
                if (!isLastLevel) _currentLevel++;
                _cachedImages = null;
              });

              Navigator.pop(bottomSheetContext);
              await Future.delayed(const Duration(milliseconds: 200));

              final overlay = Overlay.of(context);
              final overlayEntry = OverlayEntry(
                builder: (_) => Positioned.fill(
                  child: Material(
                    color: Colors.black.withOpacity(0.6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          isLastLevel
                              ? 'assets/celebration.json'
                              : 'assets/level up.json',
                          height: 200,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isLastLevel ? "🎉 Well Done!" : "Level Up!",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              overlay.insert(overlayEntry);
              final player = AudioPlayer();
              await Future.wait([
                player.play(AssetSource(
                  isLastLevel
                      ? 'audio/celebrationAudio.mp3'
                      : 'audio/completion-of-level.wav',
                )),
                Future.delayed(const Duration(milliseconds: 1500)),
              ]);
              overlayEntry.remove();

              if (!isLastLevel) {
                await Future.delayed(const Duration(milliseconds: 300));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showRandomMiniGame();
                });
              }
            },
            onWrong: () {
              _wrongAnswers++;
              Navigator.pop(bottomSheetContext);
              Future.delayed(
                const Duration(milliseconds: 600),
                _showRandomMiniGame,
              );
            },
            onFinished: () {},
          ),
        ),
      ),
    ),
  );
}



  @override
  void dispose() {
    controller.onModelLoaded.removeListener(_onModelLoaded);
    _speech.stop();
    _ttsService.stop();
    _frameTimer?.cancel();
    _recorder.closeRecorder();
    _cameraController.dispose();
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Facial: ${_facialEmotion ?? 'Unknown'}",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black),
                        ),
                        Text(
                          "Voice: ${_voiceEmotion ?? 'Not analyzed'}",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black),
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
                      backgroundColor: isDark ? Colors.grey[800] : primaryColor,
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
                      backgroundColor: isDark ? Colors.grey[800] : primaryColor,
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
