// main.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

// screens/home_page.dart
class detection extends StatelessWidget {
  const detection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection App'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AutismDetectionPage()));
                },
                child: const Text(
                  'Autism Detection',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UnifiedDetectionScreen()));
                },
                child: const Text(
                  'all Detection',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// screens/autism_detection_page.dart

class AutismDetectionPage extends StatefulWidget {
  const AutismDetectionPage({super.key});

  @override
  State<AutismDetectionPage> createState() => _AutismDetectionPageState();
}

class _AutismDetectionPageState extends State<AutismDetectionPage> {
  File? _image;
  String _result = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _getImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = '';
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.13:5002/predict'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _image!.path,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      setState(() {
        _result = responseData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autism Detection'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_image != null)
                  Image.file(
                    _image!,
                    height: 300,
                    width: 300,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _getImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: () => _getImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_result.isNotEmpty)
                  Text(
                    _result,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnifiedDetectionScreen extends StatefulWidget {
  const UnifiedDetectionScreen({Key? key}) : super(key: key);

  @override
  _UnifiedDetectionScreenState createState() => _UnifiedDetectionScreenState();
}

class _UnifiedDetectionScreenState extends State<UnifiedDetectionScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Timer? _timer;
  TabController? _tabController;
  bool _isProcessing = false;

  // Detection results
  String _emotionResult = 'No emotion detected';
  String _behaviorResult = 'No behavior detected';
  String _gazeResult = 'No gaze detected';
  double _focusPercentage = 0.0;

  // Video analysis results
  Map<String, dynamic>? _videoAnalysisResults;
  bool _isAnalyzingVideo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _startDetection();
    }
  }

  void _startDetection() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isProcessing &&
          _controller != null &&
          _controller!.value.isInitialized) {
        await _processFrame();
      }
    });
  }

  Future<void> _processFrame() async {
    try {
      _isProcessing = true;
      final XFile image = await _controller!.takePicture();

      // Process for the active tab only
      switch (_tabController!.index) {
        case 0:
          await _processEmotion(image);
          break;
        case 1:
          await _processBehavior(image);
          break;
        case 2:
          await _processGaze(image);
          break;
      }

      // Clean up temporary image file
      File(image.path).deleteSync();
    } catch (e) {
      debugPrint('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processEmotion(XFile image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.1.13:5000/emotion-detection'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('frame', image.path),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonData = json.decode(responseData);

    if (response.statusCode == 200 && mounted) {
      setState(() {
        _emotionResult = jsonData['emotion'];
      });
    }
  }

  Future<void> _processBehavior(XFile image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.1.13:5001/analyze_frame'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('frame', image.path),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final jsonData = json.decode(responseData);

    if (response.statusCode == 200 && mounted) {
      setState(() {
        _behaviorResult = jsonData['behavior'];
      });
    }
  }

  Future<void> _processGaze(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('http://192.168.1.13:5002/get_gaze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );

    if (response.statusCode == 200 && mounted) {
      final data = jsonDecode(response.body);
      setState(() {
        _gazeResult = data['focus_status'];
        _focusPercentage = data['focused_percentage'];
      });
    }
  }

  Future<void> _pickAndAnalyzeVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null) {
        setState(() {
          _isAnalyzingVideo = true;
          _videoAnalysisResults = null;
        });

        final response = await http.post(
          Uri.parse('http://192.168.1.13:5001/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'video_path': result.files.single.path,
          }),
        );

        if (response.statusCode == 200) {
          setState(() {
            _videoAnalysisResults = jsonDecode(response.body);
            _isAnalyzingVideo = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzingVideo = false;
      });
      _showError('Error analyzing video: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildDetectionCard(String title, String result, {Color? color}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (color ?? Colors.blue).withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoAnalysisResults() {
    if (_isAnalyzingVideo) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            onPressed: _pickAndAnalyzeVideo,
            child: Text(_videoAnalysisResults == null
                ? 'Select Video'
                : 'Analyze Another Video'),
          ),
          if (_videoAnalysisResults != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Analysis Results:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAnalysisSection(
                'Behavior Counts', _videoAnalysisResults!['Behavior Counts']),
            const SizedBox(height: 16),
            _buildAnalysisSection('Behavior Durations (seconds)',
                _videoAnalysisResults!['Behavior Durations (seconds)']),
            const SizedBox(height: 16),
            _buildAnalysisSection('Behavior Percentages (%)',
                _videoAnalysisResults!['Behavior Percentages (%)']),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...data.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        entry.value is double
                            ? entry.value.toStringAsFixed(2)
                            : entry.value.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Detection Suite'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Emotion'),
            Tab(text: 'Behavior'),
            Tab(text: 'Gaze'),
            Tab(text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Emotion Detection Tab
          _buildDetectionTab(
            _emotionResult,
            'Current Emotion:',
            Colors.purple,
          ),

          // Behavior Detection Tab
          _buildDetectionTab(
            _behaviorResult,
            'Current Behavior:',
            Colors.green,
          ),

          // Gaze Detection Tab
          _buildGazeTab(),

          // Video Analysis Tab
          _buildVideoAnalysisResults(),
        ],
      ),
    );
  }

  Widget _buildDetectionTab(String result, String title, Color color) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildDetectionCard(title, result, color: color),
        ),
      ],
    );
  }

  Widget _buildGazeTab() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    _gazeResult.contains('Focused') ? Colors.green : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _gazeResult,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _gazeResult.contains('Focused')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _focusPercentage / 100,
                  backgroundColor: Colors.red[100],
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                Text(
                  'Focus Rate: ${_focusPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// class EmotionDetectionScreen extends StatefulWidget {
//   const EmotionDetectionScreen({Key? key}) : super(key: key);

//   @override
//   _EmotionDetectionScreenState createState() => _EmotionDetectionScreenState();
// }

// class _EmotionDetectionScreenState extends State<EmotionDetectionScreen> {
//   CameraController? _controller;
//   String _currentEmotion = 'No emotion detected';
//   Timer? _timer;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     final frontCamera = cameras.firstWhere(
//       (camera) => camera.lensDirection == CameraLensDirection.front,
//       orElse: () => cameras.first,
//     );

//     _controller = CameraController(
//       frontCamera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );

//     await _controller!.initialize();
//     if (mounted) {
//       setState(() {});
//       // Start periodic frame capture
//       _startEmotionDetection();
//     }
//   }

//   void _startEmotionDetection() {
//     _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
//       if (!_isProcessing &&
//           _controller != null &&
//           _controller!.value.isInitialized) {
//         await _captureAndAnalyzeFrame();
//       }
//     });
//   }

//   Future<void> _captureAndAnalyzeFrame() async {
//     try {
//       _isProcessing = true;

//       // Capture frame
//       final XFile image = await _controller!.takePicture();

//       // Prepare the image file for upload
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('http://192.168.1.13:5000/emotion-detection'),
//       );

//       request.files.add(
//         await http.MultipartFile.fromPath('frame', image.path),
//       );

//       // Send the request
//       final response = await request.send();
//       final responseData = await response.stream.bytesToString();
//       final jsonData = json.decode(responseData);

//       if (response.statusCode == 200 && mounted) {
//         setState(() {
//           _currentEmotion = jsonData['emotion'];
//         });
//       }

//       // Clean up temporary image file
//       File(image.path).deleteSync();
//     } catch (e) {
//       debugPrint('Error during emotion detection: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Emotion Detection'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 3,
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.blue, width: 2),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               margin: const EdgeInsets.all(16),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: CameraPreview(_controller!),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: Container(
//               width: double.infinity,
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.blue.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blue.withOpacity(0.5)),
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text(
//                     'Detected Emotion:',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     _currentEmotion.toUpperCase(),
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue[700],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class GazeTrackingScreen extends StatefulWidget {
//   const GazeTrackingScreen({Key? key}) : super(key: key);

//   @override
//   _GazeTrackingScreenState createState() => _GazeTrackingScreenState();
// }

// class _GazeTrackingScreenState extends State<GazeTrackingScreen> {
//   CameraController? _controller;
//   Timer? _timer;
//   String _focusStatus = "Initializing...";
//   double _focusedPercentage = 0.0;
//   double _notFocusedPercentage = 0.0;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     final frontCamera = cameras.firstWhere(
//       (camera) => camera.lensDirection == CameraLensDirection.front,
//       orElse: () => cameras.first,
//     );

//     _controller = CameraController(
//       frontCamera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );

//     await _controller!.initialize();
//     if (mounted) {
//       setState(() {});
//       _startGazeTracking();
//     }
//   }

//   void _startGazeTracking() {
//     _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
//       if (!_isProcessing &&
//           _controller != null &&
//           _controller!.value.isInitialized) {
//         await _processFrame();
//       }
//     });
//   }

//   Future<void> _processFrame() async {
//     try {
//       _isProcessing = true;

//       // Capture frame
//       final image = await _controller!.takePicture();
//       final bytes = await image.readAsBytes();
//       final base64Image = base64Encode(bytes);

//       // Send to server
//       final response = await http.post(
//         Uri.parse('http://192.168.1.13:5000/get_gaze'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'image': base64Image}),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           _focusStatus = data['focus_status'];
//           _focusedPercentage = data['focused_percentage'];
//           _notFocusedPercentage = data['not_focused_percentage'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error processing frame: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   Future<void> _endSession() async {
//     try {
//       final response = await http.get(
//         Uri.parse('http://your_server_ip:5000/end_conversation'),
//       );

//       if (response.statusCode == 200) {
//         final summary = jsonDecode(response.body);
//         _showSummaryDialog(summary);
//       }
//     } catch (e) {
//       debugPrint('Error ending session: $e');
//     }
//   }

//   void _showSummaryDialog(Map<String, dynamic> summary) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Session Summary'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Total Time: ${summary['total_time']} seconds'),
//               const SizedBox(height: 8),
//               Text('Focused: ${summary['focused_percentage']}%'),
//               const SizedBox(height: 8),
//               Text('Not Focused: ${summary['not_focused_percentage']}%'),
//               const SizedBox(height: 16),
//               Text(summary['summary']),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Gaze Tracking'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.stop),
//             onPressed: _endSession,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 3,
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 border: Border.all(
//                   color: _focusStatus.contains('Focused')
//                       ? Colors.green
//                       : Colors.red,
//                   width: 2,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               margin: const EdgeInsets.all(16),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: CameraPreview(_controller!),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Container(
//               width: double.infinity,
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey[100],
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.grey[300]!),
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   Text(
//                     _focusStatus,
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: _focusStatus.contains('Focused')
//                           ? Colors.green
//                           : Colors.red,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   LinearProgressIndicator(
//                     value: _focusedPercentage / 100,
//                     backgroundColor: Colors.red[100],
//                     color: Colors.green,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Focus Rate: ${_focusedPercentage.toStringAsFixed(1)}%',
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class BehaviorAnalysisScreen extends StatefulWidget {
//   const BehaviorAnalysisScreen({Key? key}) : super(key: key);

//   @override
//   _BehaviorAnalysisScreenState createState() => _BehaviorAnalysisScreenState();
// }

// class _BehaviorAnalysisScreenState extends State<BehaviorAnalysisScreen>
//     with SingleTickerProviderStateMixin {
//   CameraController? _controller;
//   Timer? _timer;
//   String _currentBehavior = 'No behavior detected';
//   bool _isProcessing = false;
//   TabController? _tabController;
//   Map<String, dynamic>? _videoAnalysisResults;
//   bool _isAnalyzingVideo = false;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     final frontCamera = cameras.firstWhere(
//       (camera) => camera.lensDirection == CameraLensDirection.front,
//       orElse: () => cameras.first,
//     );

//     _controller = CameraController(
//       frontCamera,
//       ResolutionPreset.medium,
//       enableAudio: false,
//     );

//     await _controller!.initialize();
//     if (mounted) {
//       setState(() {});
//       _startBehaviorAnalysis();
//     }
//   }

//   void _startBehaviorAnalysis() {
//     _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
//       if (!_isProcessing &&
//           _controller != null &&
//           _controller!.value.isInitialized) {
//         await _analyzeFrame();
//       }
//     });
//   }

//   Future<void> _analyzeFrame() async {
//     try {
//       _isProcessing = true;

//       // Capture frame
//       final XFile image = await _controller!.takePicture();

//       // Prepare the image file for upload
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('http://192.168.1.13:5001/analyze_frame'),
//       );

//       request.files.add(
//         await http.MultipartFile.fromPath('frame', image.path),
//       );

//       // Send the request
//       final response = await request.send();
//       final responseData = await response.stream.bytesToString();
//       final jsonData = json.decode(responseData);

//       if (response.statusCode == 200 && mounted) {
//         setState(() {
//           _currentBehavior = jsonData['behavior'];
//         });
//       }

//       // Clean up temporary image file
//       File(image.path).deleteSync();
//     } catch (e) {
//       debugPrint('Error during behavior analysis: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   Future<void> _pickAndAnalyzeVideo() async {
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.video,
//       );

//       if (result != null) {
//         setState(() {
//           _isAnalyzingVideo = true;
//           _videoAnalysisResults = null;
//         });

//         final response = await http.post(
//           Uri.parse('http://192.168.1.13:5001/analyze'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({
//             'video_path': result.files.single.path,
//           }),
//         );

//         if (response.statusCode == 200) {
//           setState(() {
//             _videoAnalysisResults = jsonDecode(response.body);
//             _isAnalyzingVideo = false;
//           });
//         } else {
//           throw Exception('Failed to analyze video');
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isAnalyzingVideo = false;
//       });
//       _showError('Error analyzing video: $e');
//     }
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   Widget _buildVideoAnalysisResults() {
//     if (_isAnalyzingVideo) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     }

//     if (_videoAnalysisResults == null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Text('No video analysis results yet'),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _pickAndAnalyzeVideo,
//               child: const Text('Select Video'),
//             ),
//           ],
//         ),
//       );
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Analysis Results:',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           _buildResultsSection(
//               'Behavior Counts', _videoAnalysisResults!['Behavior Counts']),
//           const SizedBox(height: 16),
//           _buildResultsSection('Behavior Durations (seconds)',
//               _videoAnalysisResults!['Behavior Durations (seconds)']),
//           const SizedBox(height: 16),
//           _buildResultsSection('Behavior Percentages (%)',
//               _videoAnalysisResults!['Behavior Percentages (%)']),
//           const SizedBox(height: 24),
//           Center(
//             child: ElevatedButton(
//               onPressed: _pickAndAnalyzeVideo,
//               child: const Text('Analyze Another Video'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildResultsSection(String title, Map<String, dynamic> data) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//         Card(
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               children: data.entries.map((entry) {
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(entry.key),
//                       Text(
//                         entry.value is double
//                             ? entry.value.toStringAsFixed(2)
//                             : entry.value.toString(),
//                         style: const TextStyle(fontWeight: FontWeight.w500),
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.dispose();
//     _tabController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Behavior Analysis'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'Real-time Analysis'),
//             Tab(text: 'Video Analysis'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // Real-time Analysis Tab
//           _controller == null || !_controller!.value.isInitialized
//               ? const Center(child: CircularProgressIndicator())
//               : Column(
//                   children: [
//                     Expanded(
//                       flex: 3,
//                       child: Container(
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.blue, width: 2),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         margin: const EdgeInsets.all(16),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(10),
//                           child: CameraPreview(_controller!),
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 1,
//                       child: Container(
//                         width: double.infinity,
//                         margin: const EdgeInsets.all(16),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                           border:
//                               Border.all(color: Colors.blue.withOpacity(0.5)),
//                         ),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Text(
//                               'Current Behavior:',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               _currentBehavior.toUpperCase(),
//                               style: TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue[700],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),

//           // Video Analysis Tab
//           _buildVideoAnalysisResults(),
//         ],
//       ),
//     );
//   }
// }
