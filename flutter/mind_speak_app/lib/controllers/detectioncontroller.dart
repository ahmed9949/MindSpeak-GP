import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DetectionController with ChangeNotifier {
  final FirebaseFirestore _firestore;

  DetectionController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
  final String baseUrl = 'http://192.168.1.10:5000'; // Change to your Flask IP

  /// 🔍 Behavior Detection
  Future<Map<String, dynamic>?> analyzeBehavior(File frame) async {
    final uri = Uri.parse('$baseUrl/analyze_frame');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    }
    return null;
  }

  /// 😊 Emotion Detection (from image)
  Future<Map<String, dynamic>?> analyzeEmotionFromImage(File frame) async {
    final uri = Uri.parse('$baseUrl/emotion-detection');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('frame', frame.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    }
    return null;
  }

  /// 🎧 Emotion Detection (from voice)
  Future<Map<String, dynamic>?> analyzeEmotionFromVoice(File audioFile) async {
    final uri = Uri.parse('$baseUrl/predict-emotion');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    }
    return null;
  }

  /// 👁️ Gaze Detection (from base64 image)
  Future<Map<String, dynamic>?> analyzeGazeFromBase64(
      String base64Image) async {
    final uri = Uri.parse('$baseUrl/get_gaze');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"image": base64Image}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  /// 🎥 Gaze Detection (from video)
  Future<Map<String, dynamic>?> analyzeGazeFromVideo(String videoPath) async {
    final uri = Uri.parse('$baseUrl/analyze-video');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"video_path": videoPath}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  /// 🧾 End conversation (gaze summary)
  Future<Map<String, dynamic>?> endConversationAndFetchSummary() async {
    final uri = Uri.parse('$baseUrl/end_conversation');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
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
