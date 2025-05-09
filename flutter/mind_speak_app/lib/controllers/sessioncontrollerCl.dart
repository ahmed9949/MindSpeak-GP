// lib/controllers/session/session_controller.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
import 'package:mind_speak_app/models/recommendation.dart';
import 'package:mind_speak_app/models/session_statistics.dart';
import 'package:mind_speak_app/models/sessiondata.dart';
import 'package:mind_speak_app/models/sessionstate.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';

class SessionController extends ChangeNotifier {
  final SessionRepository _repository;

  // Current session state
  SessionState _state = SessionState();
  SessionState get state => _state;

  // Analytics data
  int _childMessageCount = 0;
  int _drMessageCount = 0;
  int _totalWords = 0;

  // Session timing
  DateTime? _startTime;

  SessionController(this._repository);

  /// Starts a new therapy session
  Future<void> startSession(String childId, String therapistId) async {
    try {
      _setState(SessionStatus.starting);

      final sessionData = await _repository.startSession(childId, therapistId);
      _startTime = sessionData.startTime;

      _setState(
        SessionStatus.active,
        sessionId: sessionData.sessionId,
        sessionNumber: sessionData.sessionNumber,
        startTime: sessionData.startTime,
      );
    } catch (e) {
      _setError('Failed to start session: $e');
    }
  }

  /// Adds a message from the child to the conversation
  Future<void> addChildMessage(String message) async {
    if (_state.sessionId == null || _state.status != SessionStatus.active) {
      _setError('No active session');
      return;
    }

    try {
      await _repository.addMessage(_state.sessionId!, 'child', message);

      final updatedConversation =
          List<Map<String, String>>.from(_state.conversation);
      updatedConversation.add({'child': message});

      _setState(
        _state.status,
        conversation: updatedConversation,
      );

      // Update analytics
      _childMessageCount++;
      _totalWords += message.split(' ').length;
    } catch (e) {
      _setError('Failed to add child message: $e');
    }
  }

  /// Adds a message from the therapist/AI to the conversation
  Future<void> addTherapistMessage(String message) async {
    if (_state.sessionId == null || _state.status != SessionStatus.active) {
      _setError('No active session');
      return;
    }

    try {
      await _repository.addMessage(_state.sessionId!, 'dr', message);

      final updatedConversation =
          List<Map<String, String>>.from(_state.conversation);
      updatedConversation.add({'dr': message});

      _setState(
        _state.status,
        conversation: updatedConversation,
      );

      // Update analytics
      _drMessageCount++;
      _totalWords += message.split(' ').length;
    } catch (e) {
      _setError('Failed to add therapist message: $e');
    }
  }

  Future<SessionStatistics> endSession(
    Map<String, dynamic>? detectionStats, {
    int totalScore = 0,
    int levelsCompleted = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
    int timeSpent = 0,
  }) async {
    if (_state.sessionId == null || _state.status != SessionStatus.active) {
      _setError('No active session to end');
      throw Exception('No active session to end');
    }

    try {
      _setState(SessionStatus.ending);

      final now = DateTime.now();
      final sessionDuration = now.difference(_startTime!);

      // Make sure timeSpent is correctly set if passed as 0
      final actualTimeSpent =
          timeSpent > 0 ? timeSpent : sessionDuration.inSeconds;

      final totalMessages = _childMessageCount + _drMessageCount;
      final wordsPerMessage =
          totalMessages > 0 ? _totalWords ~/ totalMessages : 0;

      // Add mini-game stats inside the SessionStatistics object
      final stats = SessionStatistics(
        totalMessages: totalMessages,
        childMessages: _childMessageCount,
        drMessages: _drMessageCount,
        sessionDuration:
            Duration(seconds: actualTimeSpent), // Use the more accurate value
        sessionDate: _startTime!,
        wordsPerMessage: wordsPerMessage,
        sessionNumber: _state.sessionNumber,
        detectionStats: detectionStats,
        progress: {
          'levelsCompleted': levelsCompleted,
          'score': totalScore,
          'miniGameStats': {
            'correctAnswers': correctAnswers,
            'wrongAnswers': wrongAnswers,
            'timeSpent': actualTimeSpent,
          },
        },
      );

      print("Ending session with stats: ${stats.toJson()}");

      // Save basic session data
      await _repository.endSession(_state.sessionId!, stats);
      await _repository.saveSessionStatistics(_state.sessionId!, stats);

      // FIX: Get the childId from the session using the sessionId
      final sessionData = await _repository.getSession(_state.sessionId!);
      if (sessionData != null) {
        final childId = sessionData.childId;
        // Now use the childId we got from the sessionData
        await _repository.updateChildAggregateStats(childId, stats);
      } else {
        print(
            "❌ Warning: Could not get session data to update child aggregate stats");
      }

      // Save statistics and end time in Firestore
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(_state.sessionId!);

      await sessionRef.update({
        'statistics': stats.toJson(),
        'endTime': now.toIso8601String(),
      });

      _setState(
        SessionStatus.completed,
        endTime: now,
      );

      return stats;
    } catch (e) {
      _setError('Failed to end session: $e');
      throw Exception('Failed to end session: $e');
    }
  }

  /// Generates and saves recommendations based on the session
  Future<Recommendation> generateRecommendations(String childId,
      String parentsRecommendation, String therapistRecommendation) async {
    if (_state.sessionId == null) {
      _setError('No session ID available');
      throw Exception('No session ID available');
    }

    try {
      final recommendation = Recommendation(
        childId: childId,
        parentsRecommendation: parentsRecommendation,
        therapistRecommendation: therapistRecommendation,
        timestamp: DateTime.now(),
      );

      await _repository.saveRecommendations(_state.sessionId!, recommendation);
      return recommendation;
    } catch (e) {
      _setError('Failed to generate recommendations: $e');
      throw Exception('Failed to generate recommendations: $e');
    }
  }

  /// Gets all sessions for a child
  Future<List<SessionData>> getSessionsForChild(String childId) async {
    try {
      return await _repository.getSessionsForChild(childId);
    } catch (e) {
      _setError('Failed to get sessions: $e');
      return [];
    }
  }

  /// Gets a specific session by ID
  Future<SessionData?> getSessionById(String sessionId) async {
    try {
      return await _repository.getSession(sessionId);
    } catch (e) {
      _setError('Failed to get session: $e');
      return null;
    }
  }

  /// Calculates the current session duration
  Duration getCurrentSessionDuration() {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Private helper to update state
  void _setState(
    SessionStatus status, {
    String? sessionId,
    List<Map<String, String>>? conversation,
    int? sessionNumber,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    _state = _state.copyWith(
      status: status,
      sessionId: sessionId,
      conversation: conversation,
      sessionNumber: sessionNumber,
      startTime: startTime,
      endTime: endTime,
      errorMessage: null, // Clear any error
    );
    notifyListeners();
  }

  /// Private helper to set error state
  void _setError(String message) {
    _state = _state.copyWith(
      status: SessionStatus.error,
      errorMessage: message,
    );
    notifyListeners();
  }

  /// Reset controller state (e.g., when navigating away)
  void reset() {
    _state = SessionState();
    _childMessageCount = 0;
    _drMessageCount = 0;
    _totalWords = 0;
    _startTime = null;
    notifyListeners();
  }
}

class SessionAnalyzerController {
  final ChatGptModel _model;

  SessionAnalyzerController(this._model);

  Future<Map<String, String>> generateRecommendations({
    required Map<String, dynamic> childData,
    required List<SessionData> recentSessions,
    required Map<String, dynamic> aggregateStats,
  }) async {
    // Clear any existing conversation history
    _model.clearConversation();

    final String childInfo = '''
Child Information:
- Name: ${childData['name']}
- Age: ${childData['age']}
- Main Interest: ${childData['childInterest']}
    ''';

    final String sessionStats = '''
Session Statistics:
- Total Sessions: ${aggregateStats['totalSessions']}
- Average Session Duration: ${aggregateStats['averageSessionDuration']} minutes
- Average Messages per Session: ${aggregateStats['averageMessagesPerSession']}
    ''';

    String conversationSummary = 'Recent Sessions:\n';
    for (var session in recentSessions) {
      conversationSummary += '\nSession #${session.sessionNumber}:\n';
      for (var message in session.conversation) {
        message.forEach((speaker, text) {
          conversationSummary += '$speaker: $text\n';
        });
      }
    }

    final String analysisPrompt = '''
You are a specialized AI consultant analyzing therapy sessions for a child with autism.

$childInfo

$sessionStats

$conversationSummary

Based on these interactions, please provide two separate recommendations in Arabic:

1. For Parents:
- Focus on practical, implementable advice
- Include specific activities or approaches they can try at home
- Highlight positive patterns and areas for improvement
- Keep it supportive and encouraging

2. For Therapists:
- Focus on professional therapeutic strategies
- Identify communication patterns and areas of progress
- Suggest specific therapeutic approaches based on the child's responses
- Include recommendations for future sessions

Please structure your response in clear sections for parents and therapists.
''';

    try {
      // Send the complete prompt with all context
      final response = await _model.sendMessage(analysisPrompt);
      return _splitRecommendations(response);
    } catch (e) {
      return {
        'parents': 'عذراً، حدث خطأ في توليد التوصيات للوالدين.',
        'therapists': 'عذراً، حدث خطأ في توليد التوصيات للمعالجين.'
      };
    }
  }

  Map<String, String> _splitRecommendations(String fullText) {
    final parts = fullText.split('2.');
    if (parts.length != 2) {
      return {'parents': fullText, 'therapists': ''};
    }
    String parentsSection = parts[0].replaceFirst('1.', '').trim();
    String therapistsSection = parts[1].trim();
    return {'parents': parentsSection, 'therapists': therapistsSection};
  }
}
