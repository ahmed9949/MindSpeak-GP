 class SessionData {
  final String sessionId;
  final String childId;
  final String therapistId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Map<String, String>> conversation;
  final Map<String, dynamic>? statistics;
  final Map<String, dynamic>? recommendations;
  final int sessionNumber;

  SessionData({
    required this.sessionId,
    required this.childId,
    required this.therapistId,
    required this.startTime,
    this.endTime,
    required this.conversation,
    this.statistics,
    this.recommendations,
    required this.sessionNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'childId': childId,
      'therapistId': therapistId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'conversation': conversation,
      'statistics': statistics,
      'recommendations': recommendations,
      'sessionNumber': sessionNumber,
    };
  }

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      sessionId: json['sessionId'],
      childId: json['childId'],
      therapistId: json['therapistId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      conversation: List<Map<String, String>>.from(
        (json['conversation'] ?? []).map((x) => Map<String, String>.from(x)),
      ),
      statistics: json['statistics'],
      recommendations: json['recommendations'],
      sessionNumber: json['sessionNumber'] ?? 0,
    );
  }
}

 