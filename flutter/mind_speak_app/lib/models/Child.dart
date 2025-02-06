class ChildModel {
  final String childId;
  final String userId;
  final String name;
  final int age;
  final String childInterest;
  final String childPhoto;
  final int parentNumber;
  final String therapistId;
  final bool assigned;

  ChildModel({
    required this.childId,
    required this.userId,
    required this.name,
    required this.age,
    required this.childInterest,
    required this.childPhoto,
    required this.parentNumber,
    this.therapistId = '',
    this.assigned = false,
  });

  factory ChildModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChildModel(
      childId: id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      childInterest: data['childInterest'] ?? '',
      childPhoto: data['childPhoto'] ?? '',
      parentNumber: data['parentnumber'] ?? 0,
      therapistId: data['therapistId'] ?? '',
      assigned: data['assigned'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'age': age,
      'childInterest': childInterest,
      'childPhoto': childPhoto,
      'parentnumber': parentNumber,
      'therapistId': therapistId,
      'assigned': assigned,
    };
  }

  ChildModel copyWith({
    String? childId,
    String? userId,
    String? name,
    int? age,
    String? childInterest,
    String? childPhoto,
    int? parentNumber,
    String? therapistId,
    bool? assigned,
  }) {
    return ChildModel(
      childId: childId ?? this.childId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      age: age ?? this.age,
      childInterest: childInterest ?? this.childInterest,
      childPhoto: childPhoto ?? this.childPhoto,
      parentNumber: parentNumber ?? this.parentNumber,
      therapistId: therapistId ?? this.therapistId,
      assigned: assigned ?? this.assigned,
    );
  }
}
