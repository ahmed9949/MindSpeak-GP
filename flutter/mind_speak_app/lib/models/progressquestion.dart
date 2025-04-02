class ProgressModel {
  final String id;
  final String question;
  final String difficulty; // Changed from DifficultyLevel to String

  ProgressModel({
    required this.id,
    required this.question,
    required this.difficulty,
  });

  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    return ProgressModel(
      id: json['id'],
      question: json['question'],
      difficulty: json['difficulty'], // Directly use the string value
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'difficulty': difficulty, // Save only the string value
    };
  }
}

// Keep the enum for reference, but we'll use its string values
enum DifficultyLevel {
  low,
  mid,
  high,
}