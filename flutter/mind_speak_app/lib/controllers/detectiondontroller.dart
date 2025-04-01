// lib/controllers/detection_controller.dart

import 'package:mind_speak_app/Repositories/detectionrepository.dart';
 
class DetectionController {
  final DetectionRepository detectionRepo;

  DetectionController({required this.detectionRepo});

  // Process an image frame (base64 encoded) for detection.
  Future<Map<String, dynamic>> processFrame(String base64Image) async {
    try {
      return await detectionRepo.processFrame(base64Image);
    } catch (e) {
      throw Exception("Error in DetectionController - processFrame: $e");
    }
  }

  // Get aggregated detection statistics.
  Map<String, dynamic> getSessionStats() {
    return detectionRepo.getSessionStats();
  }

  // Reset detection statistics.
  void resetDetectionStats() {
    detectionRepo.resetStats();
  }
}
