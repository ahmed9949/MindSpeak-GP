// lib/controllers/session_controller.dart

import 'package:mind_speak_app/Repositories/sessionrepository.dart';
import 'package:mind_speak_app/models/sessionmodel.dart';

class SessionController {
  final SessionRepository sessionRepo;

  SessionController({required this.sessionRepo});

  // Fetch child data using the repository
  Future<Map<String, dynamic>?> fetchChildData(String childId) async {
    try {
      return await sessionRepo.getChildData(childId);
    } catch (e) {
      throw Exception("Error in SessionController - fetchChildData: $e");
    }
  }

  // Start a new session by creating a SessionData model and saving it through the repository
  Future<void> startNewSession(SessionData sessionData) async {
    try {
      await sessionRepo.startSession(sessionData);
    } catch (e) {
      throw Exception("Error in SessionController - startNewSession: $e");
    }
  }

  // Update session statistics after a session ends
  Future<void> updateSessionStatistics(
      String sessionId, SessionStatistics stats) async {
    try {
      await sessionRepo.updateSessionStatistics(sessionId, stats);
    } catch (e) {
      throw Exception(
          "Error in SessionController - updateSessionStatistics: $e");
    }
  }

  // End a session (e.g., set endTime)
  Future<void> endSession(String sessionId) async {
    try {
      await sessionRepo.endSession(sessionId);
    } catch (e) {
      throw Exception("Error in SessionController - endSession: $e");
    }
  }
}
