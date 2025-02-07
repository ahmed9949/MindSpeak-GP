import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ConversationMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp,
    };
  }
}

class SessionData {
  final String sessionId;
  final String childId;
  final String therapistId;
  final DateTime date;
  final int sessionNumber;
  final List<ConversationMessage> messages;

  SessionData({
    required this.sessionId,
    required this.childId,
    required this.therapistId,
    required this.date,
    required this.sessionNumber,
    required this.messages,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'childId': childId,
      'therapistId': therapistId,
      'date': date,
      'sessionNumber': sessionNumber,
      'messages': messages.map((msg) => msg.toMap()).toList(),
    };
  }
}

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get session count for a child
  Future<int> getSessionCount(String childId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting session count: $e');
      return 0;
    }
  }

  // Create a new session
  Future<String> createSession({
    required String childId,
    required String therapistId,
  }) async {
    try {
      // Get current session count
      int sessionCount = await getSessionCount(childId);
      
      // Create new session document
      DocumentReference sessionRef = await _firestore.collection('sessions').add({
        'childId': childId,
        'therapistId': therapistId,
        'date': DateTime.now(),
        'sessionNumber': sessionCount + 1,
        'messages': [],
        'status': 'active'
      });

      return sessionRef.id;
    } catch (e) {
      print('Error creating session: $e');
      throw e;
    }
  }

  // Add message to session
  Future<void> addMessageToSession(
    String sessionId,
    ConversationMessage message,
  ) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'messages': FieldValue.arrayUnion([message.toMap()])
      });
    } catch (e) {
      print('Error adding message: $e');
      throw e;
    }
  }

  // End session
  Future<void> endSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'completed',
        'endTime': DateTime.now(),
      });
    } catch (e) {
      print('Error ending session: $e');
      throw e;
    }
  }

  // Get session history for a child
  Future<List<SessionData>> getChildSessionHistory(String childId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('sessions')
          .where('childId', isEqualTo: childId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<ConversationMessage> messages = (data['messages'] as List)
            .map((msg) => ConversationMessage(
                  text: msg['text'],
                  isUser: msg['isUser'],
                  timestamp: (msg['timestamp'] as Timestamp).toDate(),
                ))
            .toList();

        return SessionData(
          sessionId: doc.id,
          childId: data['childId'],
          therapistId: data['therapistId'],
          date: (data['date'] as Timestamp).toDate(),
          sessionNumber: data['sessionNumber'],
          messages: messages,
        );
      }).toList();
    } catch (e) {
      print('Error getting session history: $e');
      throw e;
    }
  }

  // Get therapist info
  Future<Map<String, dynamic>> getTherapistInfo(String therapistId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('therapist')
          .doc(therapistId)
          .get();
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error getting therapist info: $e');
      throw e;
    }
  }

  // Get child info
  Future<Map<String, dynamic>> getChildInfo(String childId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('child')
          .doc(childId)
          .get();
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error getting child info: $e');
      throw e;
    }
  }
}

// Session Manager Provider
class SessionManagerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  String? _currentSessionId;
  String? _childId;
  String? _therapistId;
  int _sessionCount = 0;

  String? get currentSessionId => _currentSessionId;
  int get sessionCount => _sessionCount;

  // Initialize session
  Future<void> initializeSession({
    required String childId,
    required String therapistId,
  }) async {
    try {
      _childId = childId;
      _therapistId = therapistId;
      _sessionCount = await _db.getSessionCount(childId);
      _currentSessionId = await _db.createSession(
        childId: childId,
        therapistId: therapistId,
      );
      notifyListeners();
    } catch (e) {
      print('Error initializing session: $e');
      throw e;
    }
  }

  // Save message
  Future<void> saveMessage(String text, bool isUser) async {
    if (_currentSessionId == null) return;

    try {
      ConversationMessage message = ConversationMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      );
      await _db.addMessageToSession(_currentSessionId!, message);
    } catch (e) {
      print('Error saving message: $e');
      throw e;
    }
  }

  // End current session
  Future<void> endCurrentSession() async {
    if (_currentSessionId == null) return;

    try {
      await _db.endSession(_currentSessionId!);
      _currentSessionId = null;
      notifyListeners();
    } catch (e) {
      print('Error ending session: $e');
      throw e;
    }
  }

  // Get session history
  Future<List<SessionData>> getSessionHistory() async {
    if (_childId == null) return [];

    try {
      return await _db.getChildSessionHistory(_childId!);
    } catch (e) {
      print('Error getting session history: $e');
      return [];
    }
  }
}