class Recommendation {
  final String childId;
  final String parentsRecommendation;
  final String therapistRecommendation;
  final DateTime timestamp;

  Recommendation({
    required this.childId,
    required this.parentsRecommendation,
    required this.therapistRecommendation,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'childId': childId,
      'parents': parentsRecommendation,
      'therapists': therapistRecommendation,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      childId: json['childId'] ?? '',
      parentsRecommendation: json['parents'] ?? '',
      therapistRecommendation: json['therapists'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
