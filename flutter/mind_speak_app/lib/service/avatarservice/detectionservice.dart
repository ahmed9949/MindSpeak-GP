// lib/services/detection_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DetectionService {
  static const String gazeUrl = 'http://localhost:5002/get_gaze';
  static const String behaviorUrl = 'http://localhost:5001/analyze_frame';
  static const String emotionUrl = 'http://localhost:5000/emotion-detection';

  // For storing session statistics
  Map<String, dynamic> detectionStats = {
    'gaze': {
      'focused_frames': 0,
      'not_focused_frames': 0,
      'total_frames': 0,
    },
    'behavior': {
      'counts': {},
      'total_frames': 0,
    },
    'emotion': {
      'counts': {},
      'total_frames': 0,
    }
  };

  Future<Map<String, dynamic>> processFrame(String base64Image) async {
    try {
      final results = await Future.wait([
        _detectWithRetry(() => _detectGaze(base64Image)),
        _detectWithRetry(() => _detectBehavior(base64Image)),
        _detectWithRetry(() => _detectEmotion(base64Image)),
      ]);

      _updateStats(
        gazeResult: results[0],
        behaviorResult: results[1],
        emotionResult: results[2],
      );

      return {
        'gaze': results[0],
        'behavior': results[1],
        'emotion': results[2],
      };
    } catch (e) {
      print('Error processing frame: $e');
      return {};
    }
  }

  Future<T> _detectWithRetry<T>(Future<T> Function() detection) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        return await detection();
      } catch (e) {
        attempts++;
        if (attempts == maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }

    throw 'Maximum retry attempts reached';
  }

  Future<Map<String, dynamic>> _detectGaze(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse(gazeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Gaze detection failed'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _detectBehavior(String base64Image) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(behaviorUrl))
        ..files.add(
          http.MultipartFile.fromBytes(
            'frame',
            base64Decode(base64Image),
            filename: 'frame.jpg',
          ),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseData);
      }
      return {'error': 'Behavior detection failed'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _detectEmotion(String base64Image) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(emotionUrl))
        ..files.add(
          http.MultipartFile.fromBytes(
            'frame',
            base64Decode(base64Image),
            filename: 'frame.jpg',
          ),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseData);
      }
      return {'error': 'Emotion detection failed'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void _updateStats({
    required Map<String, dynamic> gazeResult,
    required Map<String, dynamic> behaviorResult,
    required Map<String, dynamic> emotionResult,
  }) {
    // Update gaze statistics
    if (gazeResult['focus_status'] != null) {
      detectionStats['gaze']['total_frames']++;
      if (gazeResult['focus_status'] == '✅ Focused on Avatar') {
        detectionStats['gaze']['focused_frames']++;
      } else {
        detectionStats['gaze']['not_focused_frames']++;
      }
    }

    // Update behavior statistics
    if (behaviorResult['behavior'] != null) {
      detectionStats['behavior']['total_frames']++;
      final behavior = behaviorResult['behavior'];
      detectionStats['behavior']['counts'][behavior] =
          (detectionStats['behavior']['counts'][behavior] ?? 0) + 1;
    }

    // Update emotion statistics
    if (emotionResult['emotion'] != null) {
      detectionStats['emotion']['total_frames']++;
      final emotion = emotionResult['emotion'];
      detectionStats['emotion']['counts'][emotion] =
          (detectionStats['emotion']['counts'][emotion] ?? 0) + 1;
    }
  }

  Map<String, dynamic> getSessionStats() {
    return {
      'detection_stats': detectionStats,
      'gaze_focus_percentage': detectionStats['gaze']['total_frames'] > 0
          ? (detectionStats['gaze']['focused_frames'] /
                  detectionStats['gaze']['total_frames'] *
                  100)
              .toStringAsFixed(2)
          : '0',
      'behavior_summary': _calculatePercentages(
          detectionStats['behavior']['counts'],
          detectionStats['behavior']['total_frames']),
      'emotion_summary': _calculatePercentages(
          detectionStats['emotion']['counts'],
          detectionStats['emotion']['total_frames']),
    };
  }

  Map<String, String> _calculatePercentages(
      Map<String, int> counts, int total) {
    if (total == 0) return {};
    return counts.map((key, value) =>
        MapEntry(key, ((value / total) * 100).toStringAsFixed(2)));
  }

  void resetStats() {
    detectionStats = {
      'gaze': {
        'focused_frames': 0,
        'not_focused_frames': 0,
        'total_frames': 0,
      },
      'behavior': {
        'counts': {},
        'total_frames': 0,
      },
      'emotion': {
        'counts': {},
        'total_frames': 0,
      }
    };
  }
}
