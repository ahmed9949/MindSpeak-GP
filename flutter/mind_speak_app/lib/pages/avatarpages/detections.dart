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
        Uri.parse('http://172.20.10.5:5004/predict'),
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Reduced to 3 tabs
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
      Uri.parse('http://172.20.10.5:5000/emotion-detection'),
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
      Uri.parse('http://172.20.10.5:5001/analyze_frame'),
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
      Uri.parse('http://172.20.10.5:5002/get_gaze'),
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

// class _UnifiedDetectionScreenState extends State<UnifiedDetectionScreen>
//     with SingleTickerProviderStateMixin {
//   CameraController? _controller;
//   Timer? _timer;
//   TabController? _tabController;
//   bool _isProcessing = false;

//   // Detection results
//   String _emotionResult = 'No emotion detected';
//   String _behaviorResult = 'No behavior detected';
//   String _gazeResult = 'No gaze detected';
//   double _focusPercentage = 0.0;

//   // Video analysis results
//   Map<String, dynamic>? _videoAnalysisResults;
//   bool _isAnalyzingVideo = false;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
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
//       _startDetection();
//     }
//   }

//   void _startDetection() {
//     _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
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
//       final XFile image = await _controller!.takePicture();

//       // Process for the active tab only
//       switch (_tabController!.index) {
//         case 0:
//           await _processEmotion(image);
//           break;
//         case 1:
//           await _processBehavior(image);
//           break;
//         case 2:
//           await _processGaze(image);
//           break;
//       }

//       // Clean up temporary image file
//       File(image.path).deleteSync();
//     } catch (e) {
//       debugPrint('Error processing frame: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   Future<void> _processEmotion(XFile image) async {
//     var request = http.MultipartRequest(
//       'POST',
//       Uri.parse('http://172.20.10.5:5000/emotion-detection'),
//     );

//     request.files.add(
//       await http.MultipartFile.fromPath('frame', image.path),
//     );

//     final response = await request.send();
//     final responseData = await response.stream.bytesToString();
//     final jsonData = json.decode(responseData);

//     if (response.statusCode == 200 && mounted) {
//       setState(() {
//         _emotionResult = jsonData['emotion'];
//       });
//     }
//   }

//   Future<void> _processBehavior(XFile image) async {
//     var request = http.MultipartRequest(
//       'POST',
//       Uri.parse('http://172.20.10.5:5001/analyze_frame'),
//     );

//     request.files.add(
//       await http.MultipartFile.fromPath('frame', image.path),
//     );

//     final response = await request.send();
//     final responseData = await response.stream.bytesToString();
//     final jsonData = json.decode(responseData);

//     if (response.statusCode == 200 && mounted) {
//       setState(() {
//         _behaviorResult = jsonData['behavior'];
//       });
//     }
//   }

//   Future<void> _processGaze(XFile image) async {
//     final bytes = await image.readAsBytes();
//     final base64Image = base64Encode(bytes);

//     final response = await http.post(
//       Uri.parse('http://172.20.10.5:5002/get_gaze'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'image': base64Image}),
//     );

//     if (response.statusCode == 200 && mounted) {
//       final data = jsonDecode(response.body);
//       setState(() {
//         _gazeResult = data['focus_status'];
//         _focusPercentage = data['focused_percentage'];
//       });
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
//           Uri.parse('http://172.20.10.5:5001/analyze'),
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

//   Widget _buildDetectionCard(String title, String result, {Color? color}) {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: (color ?? Colors.blue).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: (color ?? Colors.blue).withOpacity(0.5)),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             result.toUpperCase(),
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: color ?? Colors.blue[700],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoAnalysisResults() {
//     if (_isAnalyzingVideo) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           ElevatedButton(
//             onPressed: _pickAndAnalyzeVideo,
//             child: Text(_videoAnalysisResults == null
//                 ? 'Select Video'
//                 : 'Analyze Another Video'),
//           ),
//           if (_videoAnalysisResults != null) ...[
//             const SizedBox(height: 16),
//             const Text(
//               'Analysis Results:',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             _buildAnalysisSection(
//                 'Behavior Counts', _videoAnalysisResults!['Behavior Counts']),
//             const SizedBox(height: 16),
//             _buildAnalysisSection('Behavior Durations (seconds)',
//                 _videoAnalysisResults!['Behavior Durations (seconds)']),
//             const SizedBox(height: 16),
//             _buildAnalysisSection('Behavior Percentages (%)',
//                 _videoAnalysisResults!['Behavior Percentages (%)']),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildAnalysisSection(String title, Map<String, dynamic> data) {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
//             ),
//             const SizedBox(height: 8),
//             ...data.entries.map((entry) => Padding(
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
//                 )),
//           ],
//         ),
//       ),
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
//         title: const Text('AI Detection Suite'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'Emotion'),
//             Tab(text: 'Behavior'),
//             Tab(text: 'Gaze'),
//             Tab(text: 'Video'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // Emotion Detection Tab
//           _buildDetectionTab(
//             _emotionResult,
//             'Current Emotion:',
//             Colors.purple,
//           ),

//           // Behavior Detection Tab
//           _buildDetectionTab(
//             _behaviorResult,
//             'Current Behavior:',
//             Colors.green,
//           ),

//           // Gaze Detection Tab
//           _buildGazeTab(),

//           // Video Analysis Tab
//           _buildVideoAnalysisResults(),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetectionTab(String result, String title, Color color) {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Column(
//       children: [
//         Expanded(
//           flex: 3,
//           child: Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               border: Border.all(color: color, width: 2),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             margin: const EdgeInsets.all(16),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(10),
//               child: CameraPreview(_controller!),
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 1,
//           child: _buildDetectionCard(title, result, color: color),
//         ),
//       ],
//     );
//   }

//   Widget _buildGazeTab() {
//     if (_controller == null || !_controller!.value.isInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Column(
//       children: [
//         Expanded(
//           flex: 3,
//           child: Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               border: Border.all(
//                 color:
//                     _gazeResult.contains('Focused') ? Colors.green : Colors.red,
//                 width: 2,
//               ),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             margin: const EdgeInsets.all(16),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(10),
//               child: CameraPreview(_controller!),
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 1,
//           child: Container(
//             width: double.infinity,
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.blue.withOpacity(0.5)),
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   _gazeResult,
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                     color: _gazeResult.contains('Focused')
//                         ? Colors.green
//                         : Colors.red,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 LinearProgressIndicator(
//                   value: _focusPercentage / 100,
//                   backgroundColor: Colors.red[100],
//                   color: Colors.green,
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Focus Rate: ${_focusPercentage.toStringAsFixed(1)}%',
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
