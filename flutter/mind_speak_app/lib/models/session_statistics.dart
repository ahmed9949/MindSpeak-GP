class SessionStatistics {
  final int totalMessages;
  final int childMessages;
  final int drMessages;
  final Duration sessionDuration;
  final DateTime sessionDate;
  final int wordsPerMessage;
  final int sessionNumber;
  final Map<String, dynamic>? detectionStats;
  final Map<String, dynamic>? progress;

  SessionStatistics({
    required this.totalMessages,
    required this.childMessages,
    required this.drMessages,
    required this.sessionDuration,
    required this.sessionDate,
    required this.wordsPerMessage,
    required this.sessionNumber,
    this.detectionStats,
    this.progress,
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
      'detectionStats': detectionStats,
      'progress': progress,
    };
  }

  factory SessionStatistics.fromJson(Map<String, dynamic> json) {
    return SessionStatistics(
      totalMessages: json['totalMessages'] ?? 0,
      childMessages: json['childMessages'] ?? 0,
      drMessages: json['drMessages'] ?? 0,
      sessionDuration: Duration(minutes: json['sessionDuration'] ?? 0),
      sessionDate: DateTime.parse(json['sessionDate']),
      wordsPerMessage: json['wordsPerMessage'] ?? 0,
      sessionNumber: json['sessionNumber'] ?? 0,
      detectionStats: json['detectionStats'],
    );
  }
}
