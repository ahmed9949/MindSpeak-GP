// lib/models/session_statistics.dart
class SessionStatistics {
  final int totalMessages;
  final int childMessages;
  final int drMessages;
  final Duration sessionDuration;
  final DateTime sessionDate;
  final int wordsPerMessage;
  final int sessionNumber;

  SessionStatistics({
    required this.totalMessages,
    required this.childMessages,
    required this.drMessages,
    required this.sessionDuration,
    required this.sessionDate,
    required this.wordsPerMessage,
    required this.sessionNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalMessages': totalMessages,
      'childMessages': childMessages,
      'drMessages': drMessages,
      'sessionDuration': sessionDuration.inMinutes,
      'sessionDate': sessionDate.toIso8601String(),
      'wordsPerMessage': wordsPerMessage,
      'sessionNumber': sessionNumber,
    };
  }
}

// lib/models/chat_message.dart
class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

// lib/models/chat_completion_message.dart
class ChatCompletionMessage {
  final String role;
  final String content;
  ChatCompletionMessage({required this.role, required this.content});
}

// lib/models/session_data.dart
class SessionData {
  final String sessionId;
  final String childId;
  final String therapistId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Map<String, String>> conversation;

  SessionData({
    required this.sessionId,
    required this.childId,
    required this.therapistId,
    required this.startTime,
    this.endTime,
    required this.conversation,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'childId': childId,
      'therapistId': therapistId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'conversation': conversation,
    };
  }
}