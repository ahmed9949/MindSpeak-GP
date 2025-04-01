// lib/repositories/detection_repository.dart

import 'package:mind_speak_app/service/avatarservice/detectionservice.dart';
 
class DetectionRepository {
  final DetectionService _detectionService = DetectionService();

  // Process an image frame (base64 encoded) for detection.
  Future<Map<String, dynamic>> processFrame(String base64Image) async {
    try {
      return await _detectionService.processFrame(base64Image);
    } catch (e) {
      throw Exception("Error processing detection frame: $e");
    }
  }

  // Retrieve aggregated session detection statistics.
  Map<String, dynamic> getSessionStats() {
    return _detectionService.getSessionStats();
  }

  // Reset the detection statistics.
  void resetStats() {
    _detectionService.resetStats();
  }
}
