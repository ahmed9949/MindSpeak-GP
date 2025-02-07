class CarsFormModel {
  final String formId;
  final String childId;
  final bool status;
  final double totalScore; // totalScore remains a double.
  final List<String> selectedQuestions;

  CarsFormModel({
    required this.formId,
    required this.childId,
    this.status = false,
    this.totalScore = 0.0,
    this.selectedQuestions = const [],
  });

  factory CarsFormModel.fromFirestore(Map<String, dynamic> data, String id) {
    final rawScore = data['totalScore'] ?? 0.0;
    double totalScore;
    if (rawScore is double) {
      totalScore = rawScore;
    } else if (rawScore is int) {
      totalScore = rawScore.toDouble();
    } else if (rawScore is String) {
      totalScore = double.tryParse(rawScore) ?? 0.0;
    } else {
      totalScore = 0.0;
    }

    // Convert each element in selectedQuestions to a string.
    List<String> selectedQuestions = [];
    if (data['selectedQuestions'] != null &&
        data['selectedQuestions'] is List) {
      selectedQuestions = List<String>.from(
          (data['selectedQuestions'] as List).map((e) => e.toString()));
    }

    return CarsFormModel(
      formId: id,
      childId: data['childId'] ?? '',
      status: data['status'] ?? false,
      totalScore: totalScore,
      selectedQuestions: selectedQuestions,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'status': status,
      'totalScore': totalScore,
      'selectedQuestions': selectedQuestions,
    };
  }
}
