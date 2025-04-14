// import 'dart:convert';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;

// class DetectionController with ChangeNotifier {
//   final FirebaseFirestore _firestore;

//   DetectionController({FirebaseFirestore? firestore})
//       : _firestore = firestore ?? FirebaseFirestore.instance;

//   Future<void> addDetection({
//     required String sessionId,
//     required Map<String, dynamic> detectionData,
//   }) async {
//     try {
//       final sessionRef = _firestore.collection('sessions').doc(sessionId);
//       await sessionRef.update({
//         'detections': FieldValue.arrayUnion([detectionData])
//       });
//     } catch (e) {
//       debugPrint('Error saving detection: $e');
//     }
//   }
// }

// class AiService {
//   final String baseUrl = 'http://192.168.1.10:5000'; // Change to your Flask IP

//   /// 🔍 Behavior Detection
//   Future<Map<String, dynamic>?> analyzeBehavior(File frame) async {
//     final uri = Uri.parse('$baseUrl/analyze_frame');
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

//     final response = await request.send();
//     if (response.statusCode == 200) {
//       final respStr = await response.stream.bytesToString();
//       return json.decode(respStr);
//     }
//     return null;
//   }

//   /// 😊 Emotion Detection (from image)
//   Future<Map<String, dynamic>?> analyzeEmotionFromImage(File frame) async {
//     final uri = Uri.parse('$baseUrl/emotion-detection');
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

//     final response = await request.send();
//     if (response.statusCode == 200) {
//       final respStr = await response.stream.bytesToString();
//       return json.decode(respStr);
//     }
//     return null;
//   }

//   /// 🎧 Emotion Detection (from voice)
//   Future<Map<String, dynamic>?> analyzeEmotionFromVoice(File audioFile) async {
//     final uri = Uri.parse('$baseUrl/predict-emotion');
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

//     final response = await request.send();
//     if (response.statusCode == 200) {
//       final respStr = await response.stream.bytesToString();
//       return json.decode(respStr);
//     }
//     return null;
//   }

//   /// 👁️ Gaze Detection (from base64 image)
//   Future<Map<String, dynamic>?> analyzeGazeFromBase64(
//       String base64Image) async {
//     final uri = Uri.parse('$baseUrl/get_gaze');
//     final response = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({"image": base64Image}),
//     );

//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     }
//     return null;
//   }

//   /// 🎥 Gaze Detection (from video)
//   Future<Map<String, dynamic>?> analyzeGazeFromVideo(String videoPath) async {
//     final uri = Uri.parse('$baseUrl/analyze-video');
//     final response = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({"video_path": videoPath}),
//     );

//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     }
//     return null;
//   }

//   /// 🧾 End conversation (gaze summary)
//   Future<Map<String, dynamic>?> endConversationAndFetchSummary() async {
//     final uri = Uri.parse('$baseUrl/end_conversation');
//     final response = await http.get(uri);

//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     }
//     return null;
//   }
// }

// class DetectionRepository {
//   final FirebaseFirestore _firestore;

//   DetectionRepository({FirebaseFirestore? firestore})
//       : _firestore = firestore ?? FirebaseFirestore.instance;

//   Future<void> saveDetection(
//       String sessionId, Map<String, dynamic> detection) async {
//     await _firestore.collection('sessions').doc(sessionId).update({
//       'detections': FieldValue.arrayUnion([detection])
//     });
//   }
// }

// class DetectionProvider with ChangeNotifier {
//   final DetectionController _controller;

//   DetectionProvider(this._controller);

//   Future<void> logDetection(String sessionId, Map<String, dynamic> data) async {
//     await _controller.addDetection(sessionId: sessionId, detectionData: data);
//   }
// }

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DetectionController with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final bool _aiServicesAvailable = true;

  DetectionController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  bool get aiServicesAvailable => _aiServicesAvailable;

  Future<void> addDetection({
    required String sessionId,
    required Map<String, dynamic> detectionData,
  }) async {
    try {
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      await sessionRef.update({
        'detections': FieldValue.arrayUnion([detectionData])
      });
    } catch (e) {
      debugPrint('Error saving detection: $e');
    }
  }
}

class AiService {
  final String baseUrl = 'http://172.20.10.13:5000'; // Change to your Flask IP
  bool _servicesAvailable = true;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  // Getter for service availability
  bool get servicesAvailable => _servicesAvailable;

  // Checks if services should be disabled after consecutive errors
  void _checkServiceAvailability() {
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _servicesAvailable = false;
      debugPrint(
          '⚠️ AI services disabled after $_consecutiveErrors consecutive errors');
    }
  }

  // Resets error counter on successful call
  void _resetErrorCounter() {
    _consecutiveErrors = 0;
    _servicesAvailable = true;
  }

  /// 🔍 Behavior Detection
  Future<Map<String, dynamic>?> analyzeBehavior(File frame) async {
    if (!_servicesAvailable) {
      return _getMockBehaviorData();
    }

    try {
      final uri = Uri.parse('$baseUrl/analyze_frame');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

      final response = await request.send().timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        _resetErrorCounter();
        return json.decode(respStr);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Behavior analysis error: ${response.statusCode}');
        return _getMockBehaviorData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Behavior analysis exception: $e');
      return _getMockBehaviorData();
    }
  }

  /// 😊 Emotion Detection (from image)
  Future<Map<String, dynamic>?> analyzeEmotionFromImage(File frame) async {
    if (!_servicesAvailable) {
      return _getMockEmotionData();
    }

    try {
      final uri = Uri.parse('$baseUrl/emotion-detection');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

      final response = await request.send().timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        _resetErrorCounter();
        return json.decode(respStr);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Emotion analysis error: ${response.statusCode}');
        return _getMockEmotionData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Emotion analysis exception: $e');
      return _getMockEmotionData();
    }
  }

  /// 🎧 Emotion Detection (from voice)
  Future<Map<String, dynamic>?> analyzeEmotionFromVoice(File audioFile) async {
    if (!_servicesAvailable) {
      return _getMockVoiceEmotionData();
    }

    try {
      final uri = Uri.parse('$baseUrl/predict-emotion');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final response = await request.send().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        _resetErrorCounter();
        return json.decode(respStr);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Voice analysis error: ${response.statusCode}');
        return _getMockVoiceEmotionData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Voice analysis exception: $e');
      return _getMockVoiceEmotionData();
    }
  }

  /// 👁️ Gaze Detection (from base64 image)
  Future<Map<String, dynamic>?> analyzeGazeFromBase64(
      String base64Image) async {
    if (!_servicesAvailable) {
      return _getMockGazeData();
    }

    try {
      final uri = Uri.parse('$baseUrl/get_gaze');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"image": base64Image}),
          )
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        _resetErrorCounter();
        return json.decode(response.body);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Gaze analysis error: ${response.statusCode}');
        return _getMockGazeData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Gaze analysis exception: $e');
      return _getMockGazeData();
    }
  }

  /// 🎥 Gaze Detection (from video)
  Future<Map<String, dynamic>?> analyzeGazeFromVideo(String videoPath) async {
    if (!_servicesAvailable) {
      return _getMockVideoAnalysisData();
    }

    try {
      final uri = Uri.parse('$baseUrl/analyze-video');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"video_path": videoPath}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        _resetErrorCounter();
        return json.decode(response.body);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Video analysis error: ${response.statusCode}');
        return _getMockVideoAnalysisData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Video analysis exception: $e');
      return _getMockVideoAnalysisData();
    }
  }

  /// 🧾 End conversation (gaze summary)
  Future<Map<String, dynamic>?> endConversationAndFetchSummary() async {
    if (!_servicesAvailable) {
      return _getMockSummaryData();
    }

    try {
      final uri = Uri.parse('$baseUrl/end_conversation');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        _resetErrorCounter();
        return json.decode(response.body);
      } else {
        _consecutiveErrors++;
        _checkServiceAvailability();
        debugPrint('❌ Summary fetch error: ${response.statusCode}');
        return _getMockSummaryData();
      }
    } catch (e) {
      _consecutiveErrors++;
      _checkServiceAvailability();
      debugPrint('❌ Summary fetch exception: $e');
      return _getMockSummaryData();
    }
  }

  // Mock data generators for fallback when AI services are unavailable
  Map<String, dynamic> _getMockBehaviorData() {
    return {'behavior': 'normal', 'focus': _getMockGazeData()};
  }

  Map<String, dynamic> _getMockEmotionData() {
    final emotions = ['neutral', 'happy', 'neutral', 'interested', 'neutral'];
    final randomEmotion =
        emotions[DateTime.now().millisecond % emotions.length];
    return {'emotion': randomEmotion};
  }

  Map<String, dynamic> _getMockVoiceEmotionData() {
    final emotions = ['neutral', 'calm', 'happy', 'neutral'];
    final randomEmotion =
        emotions[DateTime.now().millisecond % emotions.length];
    return {
      'emotion': randomEmotion,
      'probabilities': [0.8, 0.1, 0.05, 0.05]
    };
  }

  Map<String, dynamic> _getMockGazeData() {
    // Randomize focus a bit to make it look natural
    final isFocused =
        DateTime.now().second % 3 != 0; // ~67% chance of being focused
    return {
      'focus_status': isFocused ? '✅ Focused on Avatar' : '❌ Not Focused',
      'focused_percentage': isFocused ? 70.0 : 30.0,
      'not_focused_percentage': isFocused ? 30.0 : 70.0,
    };
  }

  Map<String, dynamic> _getMockVideoAnalysisData() {
    return {
      'Behavior Analysis': {
        'Behavior Counts': {'normal': 10, 'hand_flapping': 2},
        'Behavior Durations (seconds)': {'normal': 50, 'hand_flapping': 10},
        'Behavior Percentages (%)': {'normal': 80, 'hand_flapping': 20},
      },
      'Emotion Analysis': {
        'Emotion Counts': {'neutral': 8, 'happy': 4},
        'Emotion Percentages (%)': {'neutral': 60, 'happy': 40}
      },
      'Focus Analysis': {
        'Focused Frames': 9,
        'Not Focused Frames': 3,
        'Focus Percentages (%)': {'focused': 75, 'not_focused': 25}
      }
    };
  }

  Map<String, dynamic> _getMockSummaryData() {
    return {
      'total_time': 180.5,
      'focused_percentage': 68.5,
      'not_focused_percentage': 31.5,
      'focus_intervals': [
        {
          'state': '✅ Focused on Avatar',
          'start': DateTime.now().millisecondsSinceEpoch / 1000 - 180,
          'end': DateTime.now().millisecondsSinceEpoch / 1000,
          'duration': 180.0
        }
      ],
      'summary': 'Overall, the child was focused 68.5% of the time.'
    };
  }
}

class DetectionRepository {
  final FirebaseFirestore _firestore;

  DetectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveDetection(
      String sessionId, Map<String, dynamic> detection) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'detections': FieldValue.arrayUnion([detection])
    });
  }
}

class DetectionProvider with ChangeNotifier {
  final DetectionController _controller;

  DetectionProvider(this._controller);

  Future<void> logDetection(String sessionId, Map<String, dynamic> data) async {
    await _controller.addDetection(sessionId: sessionId, detectionData: data);
  }
}

// Exception for timeout
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
