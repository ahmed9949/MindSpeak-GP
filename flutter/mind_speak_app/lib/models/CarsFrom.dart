class CarsFormModel {
  final String formId;
  final String childId;
  final bool status;

  CarsFormModel({
    required this.formId,
    required this.childId,
    this.status = false,
  });

  factory CarsFormModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CarsFormModel(
      formId: id,
      childId: data['childId'] ?? '',
      status: data['status'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'status': status,
    };
  }
}
