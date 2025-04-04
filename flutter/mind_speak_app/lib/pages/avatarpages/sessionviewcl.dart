import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image/image.dart' as img;
import 'package:mind_speak_app/controllers/detectioncontroller.dart';
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
        SnackBar(content: Text('Camera permission is required')),
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
      if (widget.initialResponse.isNotEmpty) {
        _speak(widget.initialResponse);
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

      // Log detection data
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
      setState(() => _isSpeaking = true);
      _playAnimation("newtalk");
      await _ttsService.speak(text);
      setState(() => _isSpeaking = false);
      _playAnimation("idle.001");
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

    // End session and get stats
    final stats = await sessionController.endSession({});

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
    return Scaffold(
      appBar: AppBar(title: const Text("Therapy Session")),
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

              // Optional: Emotion status display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text("Facial: ${_facialEmotion ?? 'Unknown'}"),
                    Text("Voice: ${_voiceEmotion ?? 'Not analyzed'}"),
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
                child: Text(_isListening ? "Recording..." : "Start Talking"),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
                  ),
                  ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.call_end),
                    label: const Text("End Call"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  )
                ],
              )
            ],
          ),

          // Hidden camera preview (for capturing frames)
          Positioned(
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: 0.0, // Make invisible
              child: SizedBox(
                width: 1, // Minimal size
                height: 1,
                child: _isCameraInitialized
                    ? CameraPreview(_cameraController)
                    : Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
