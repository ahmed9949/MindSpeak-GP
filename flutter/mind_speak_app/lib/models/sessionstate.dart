
// lib/models/session/session_state.dart
enum SessionStatus {
  initial,
  starting,
  active,
  ending,
  completed,
  error,
}

class SessionState {
  final String? sessionId;
  final SessionStatus status;
  final List<Map<String, String>> conversation;
  final String? errorMessage;
  final int sessionNumber;
  final DateTime? startTime;
  final DateTime? endTime;
  
  SessionState({
    this.sessionId,
    this.status = SessionStatus.initial,
    this.conversation = const [],
    this.errorMessage,
    this.sessionNumber = 0,
    this.startTime,
    this.endTime,
  });
  
  SessionState copyWith({
    String? sessionId,
    SessionStatus? status,
    List<Map<String, String>>? conversation,
    String? errorMessage,
    int? sessionNumber,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      errorMessage: errorMessage,  // Null means no change, not clearing
      sessionNumber: sessionNumber ?? this.sessionNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}