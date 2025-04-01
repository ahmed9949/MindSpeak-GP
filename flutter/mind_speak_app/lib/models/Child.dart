class ChildModel {
  final String childId;
  final String name;
  final int age;
  final String childInterest;
  final String childPhoto;
  final String therapistId;
  final bool assigned;
  final String userId; // Add this to store the parent's user ID

  ChildModel({
    required this.childId,
    required this.name,
    required this.age,
    required this.childInterest,
    required this.childPhoto,
    required this.therapistId,
    this.assigned = false,
    required this.userId, // Add this parameter
  });

  factory ChildModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChildModel(
      childId: id,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      childInterest: data['childInterest'] ?? '',
      childPhoto: data['childPhoto'] ?? '',
      therapistId: data['therapistId'] ?? '',
      assigned: data['assigned'] ?? false,
      userId: data['userId'] ?? '', // Extract from Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'age': age,
      'childInterest': childInterest,
      'childPhoto': childPhoto,
      'therapistId': therapistId,
      'assigned': assigned,
      'userId': userId, // Include in Firestore data
    };
  }
}
