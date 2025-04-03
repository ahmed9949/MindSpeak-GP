// lib/repositories/session/session_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/models/recommendation.dart';
import 'package:mind_speak_app/models/session_statistics.dart';
import 'package:mind_speak_app/models/sessiondata.dart';

abstract class SessionRepository {
  /// Starts a new session for a child
  Future<SessionData> startSession(String childId, String therapistId);

  /// Ends the active session and calculates statistics
  Future<void> endSession(String sessionId, SessionStatistics statistics);

  /// Adds a message to the session conversation
  Future<void> addMessage(String sessionId, String speaker, String message);

  /// Retrieves a session by ID
  Future<SessionData?> getSession(String sessionId);

  /// Gets all sessions for a child
  Future<List<SessionData>> getSessionsForChild(String childId);

  /// Gets the latest session for a child
  Future<SessionData?> getLatestSessionForChild(String childId);

  /// Saves session statistics
  Future<void> saveSessionStatistics(
      String sessionId, SessionStatistics statistics);

  /// Saves session recommendations
  Future<void> saveRecommendations(
      String sessionId, Recommendation recommendations);

  /// Gets the next session number for a child
  Future<int> getNextSessionNumber(String childId);

  /// Updates child aggregate statistics after a session
  Future<void> updateChildAggregateStats(
      String childId, SessionStatistics sessionStats);
}

// lib/repositories/session/firebase_session_repository.dart

class FirebaseSessionRepository implements SessionRepository {
  final FirebaseFirestore _firestore;

  FirebaseSessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<SessionData> startSession(String childId, String therapistId) async {
    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final startTime = DateTime.now();
      final sessionNumber = await getNextSessionNumber(childId);

      final sessionData = SessionData(
        sessionId: sessionId,
        childId: childId,
        therapistId: therapistId,
        startTime: startTime,
        conversation: [],
        sessionNumber: sessionNumber,
      );

      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .set(sessionData.toJson());

      return sessionData;
    } catch (e) {
      throw Exception('Error starting session: $e');
    }
  }

  @override
  Future<void> endSession(
      String sessionId, SessionStatistics statistics) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'endTime': DateTime.now().toIso8601String(),
        'statistics': statistics.toJson(),
      });
    } catch (e) {
      throw Exception('Error ending session: $e');
    }
  }

  @override
  Future<void> addMessage(
      String sessionId, String speaker, String message) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'conversation': FieldValue.arrayUnion([
          {speaker: message}
        ]),
      });
    } catch (e) {
      throw Exception('Error adding message: $e');
    }
  }

  @override
  Future<SessionData?> getSession(String sessionId) async {
    try {
      final doc = await _firestore.collection('sessions').doc(sessionId).get();

      if (!doc.exists) {
        return null;
      }

      return SessionData.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Error getting session: $e');
    }
  }

  @override
  Future<List<SessionData>> getSessionsForChild(String childId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .orderBy('sessionNumber', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SessionData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error getting sessions for child: $e');
    }
  }

  @override
  Future<SessionData?> getLatestSessionForChild(String childId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .orderBy('sessionNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return SessionData.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Error getting latest session: $e');
    }
  }

  @override
  Future<void> saveSessionStatistics(
      String sessionId, SessionStatistics statistics) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'statistics': statistics.toJson(),
      });
    } catch (e) {
      throw Exception('Error saving session statistics: $e');
    }
  }

  @override
// In FirebaseSessionRepository
  Future<void> saveRecommendations(
      String sessionId, Recommendation recommendations) async {
    try {
      // First update the session document
      await _firestore.collection('sessions').doc(sessionId).update({
        'recommendations': recommendations.toJson(),
      });

      // Then check if the child document exists before updating it
      final childDoc = await _firestore
          .collection('child')
          .doc(recommendations.childId)
          .get();

      if (childDoc.exists) {
        // Only update if the document exists
        await _firestore
            .collection('child')
            .doc(recommendations.childId)
            .update({
          'latestRecommendations': recommendations.toJson(),
        });
      } else {
        print(
            'Warning: Child document ${recommendations.childId} not found, skipping recommendations update');
      }
    } catch (e) {
      print('Error saving recommendations: $e');
      // Rethrow or handle as needed
    }
  }

  @override
  Future<int> getNextSessionNumber(String childId) async {
    try {
      final childRef = _firestore.collection('child').doc(childId);

      return await _firestore.runTransaction<int>((transaction) async {
        final childDoc = await transaction.get(childRef);

        if (!childDoc.exists) {
          throw Exception('Child document not found');
        }

        final currentCount = childDoc.data()?['sessionCount'] as int? ?? 0;
        final newCount = currentCount + 1;

        transaction.update(childRef, {'sessionCount': newCount});

        return newCount;
      });
    } catch (e) {
      throw Exception('Error getting next session number: $e');
    }
  }

  @override
  Future<void> updateChildAggregateStats(
      String childId, SessionStatistics sessionStats) async {
    try {
      final childRef = _firestore.collection('child').doc(childId);

      await _firestore.runTransaction((transaction) async {
        final childDoc = await transaction.get(childRef);

        if (!childDoc.exists) return;

        final currentStats = childDoc.data()?['aggregateStats'] ??
            {
              'totalSessions': 0,
              'totalMessages': 0,
              'averageSessionDuration': 0,
              'averageMessagesPerSession': 0,
            };

        final newTotalSessions = (currentStats['totalSessions'] as int) + 1;
        final newTotalMessages =
            (currentStats['totalMessages'] as int) + sessionStats.totalMessages;
        final newAvgDuration =
            ((currentStats['averageSessionDuration'] as int) *
                        (newTotalSessions - 1) +
                    sessionStats.sessionDuration.inMinutes) /
                newTotalSessions;
        final newAvgMessages = newTotalMessages / newTotalSessions;

        transaction.update(childRef, {
          'aggregateStats': {
            'totalSessions': newTotalSessions,
            'totalMessages': newTotalMessages,
            'averageSessionDuration': newAvgDuration.round(),
            'averageMessagesPerSession': newAvgMessages.round(),
            'lastSessionDate': DateTime.now().toIso8601String(),
          }
        });
      });
    } catch (e) {
      throw Exception('Error updating child stats: $e');
    }
  }
}
