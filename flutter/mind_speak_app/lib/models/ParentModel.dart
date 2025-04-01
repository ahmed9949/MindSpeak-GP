class ParentModel {
  final String parentId;
  final int phoneNumber;

  ParentModel({
    required this.parentId,
    required this.phoneNumber,
  });

  factory ParentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ParentModel(
      parentId: id,
      phoneNumber: data['phoneNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
    };
  }
}
