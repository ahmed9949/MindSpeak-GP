// lib/repositories/session_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/models/sessionmodel.dart';

class SessionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch child data by childId.
  Future<Map<String, dynamic>?> getChildData(String childId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('child').doc(childId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Error fetching child data: $e");
    }
  }

  // Start a new session by saving the session data.
  Future<void> startSession(SessionData sessionData) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionData.sessionId)
          .set(sessionData.toJson());
    } catch (e) {
      throw Exception("Error starting session: $e");
    }
  }

  // Update session statistics in the session document.
  Future<void> updateSessionStatistics(String sessionId, SessionStatistics stats) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'statistics': stats.toJson(),
      });
    } catch (e) {
      throw Exception("Error updating session statistics: $e");
    }
  }

  // End a session by setting the endTime.
  Future<void> endSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'endTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Error ending session: $e");
    }
  }
}
