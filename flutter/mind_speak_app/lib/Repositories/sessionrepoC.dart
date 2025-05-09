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

  Future<void> updateChildAggregateStats(
      String childId, SessionStatistics sessionStats) async {
    try {
      final childRef = _firestore.collection('child').doc(childId);

      print("Updating aggregate stats for child: $childId");
      print("Session stats being added: ${sessionStats.toJson()}");

      await _firestore.runTransaction((transaction) async {
        final childDoc = await transaction.get(childRef);

        if (!childDoc.exists) {
          print("Child document not found: $childId");
          return;
        }

        final childData = childDoc.data();
        print("Current child data: $childData");

        final currentStats = childData?['aggregateStats'] ??
            {
              'totalSessions': 0,
              'totalMessages': 0,
              'averageSessionDuration': 0,
              'averageMessagesPerSession': 0,
            };

        print("Current aggregate stats: $currentStats");

        // Use safe type casting with null/default handling
        final currentTotalSessions =
            (currentStats['totalSessions'] as num?)?.toInt() ?? 0;
        final currentTotalMessages =
            (currentStats['totalMessages'] as num?)?.toInt() ?? 0;
        final currentAvgDuration =
            (currentStats['averageSessionDuration'] as num?)?.toInt() ?? 0;

        final newTotalSessions = currentTotalSessions + 1;
        final newTotalMessages =
            currentTotalMessages + sessionStats.totalMessages;

        // Safe calculation for average
        final newAvgDuration = newTotalSessions > 0
            ? ((currentAvgDuration * (newTotalSessions - 1) +
                    sessionStats.sessionDuration.inMinutes) /
                newTotalSessions)
            : sessionStats.sessionDuration.inMinutes;

        final newAvgMessages = newTotalSessions > 0
            ? newTotalMessages / newTotalSessions
            : sessionStats.totalMessages;

        final updatedStats = {
          'totalSessions': newTotalSessions,
          'totalMessages': newTotalMessages,
          'averageSessionDuration': newAvgDuration.round(),
          'averageMessagesPerSession': newAvgMessages.round(),
          'lastSessionDate': DateTime.now().toIso8601String(),
        };

        print("Updated aggregate stats: $updatedStats");

        transaction.update(childRef, {'aggregateStats': updatedStats});
      });

      print("Successfully updated aggregate stats for child: $childId");
    } catch (e) {
      print("❌ Error updating child aggregate stats: $e");
      // Don't throw, just log the error to prevent crashing the app
    }
  }

  Future<void> recalculateAllChildStats() async {
    try {
      // Get all children
      final childrenSnapshot = await _firestore.collection('child').get();

      for (final childDoc in childrenSnapshot.docs) {
        final childId = childDoc.id;
        print("Recalculating stats for child: $childId");

        // Get all sessions for this child
        final sessionsSnapshot = await _firestore
            .collection('sessions')
            .where('childId', isEqualTo: childId)
            .get();

        if (sessionsSnapshot.docs.isEmpty) {
          print("No sessions found for child: $childId");
          continue;
        }

        int totalSessions = sessionsSnapshot.docs.length;
        int totalMessages = 0;
        int totalDuration = 0;
        DateTime? lastSessionDate;

        // Calculate aggregate stats
        for (final sessionDoc in sessionsSnapshot.docs) {
          final sessionData = sessionDoc.data();
          final stats = sessionData['statistics'] as Map<String, dynamic>?;

          if (stats != null) {
            totalMessages += (stats['totalMessages'] as num?)?.toInt() ?? 0;
            totalDuration += (stats['sessionDuration'] as num?)?.toInt() ?? 0;

            // Track latest session date
            if (sessionData['startTime'] != null) {
              final sessionDate = DateTime.parse(sessionData['startTime']);
              if (lastSessionDate == null ||
                  sessionDate.isAfter(lastSessionDate)) {
                lastSessionDate = sessionDate;
              }
            }
          }
        }

        // Calculate averages
        final avgDuration =
            totalSessions > 0 ? totalDuration / totalSessions : 0;
        final avgMessages =
            totalSessions > 0 ? totalMessages / totalSessions : 0;

        // Update child document
        await _firestore.collection('child').doc(childId).update({
          'aggregateStats': {
            'totalSessions': totalSessions,
            'totalMessages': totalMessages,
            'averageSessionDuration': avgDuration.round(),
            'averageMessagesPerSession': avgMessages.round(),
            'lastSessionDate': lastSessionDate?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          }
        });

        print("Updated stats for child: $childId");
      }

      print("✅ All child stats recalculated successfully");
    } catch (e) {
      print("❌ Error recalculating child stats: $e");
    }
  }
}
