class TherapistModel {
  final String therapistId;
  final String bio;
  final String nationalId;
  final String nationalProof;
  final String therapistImage;
  final bool status;

  TherapistModel({
    required this.therapistId,
    required this.bio,
    required this.nationalId,
    required this.nationalProof,
    required this.therapistImage,
    this.status = false,
  });

  factory TherapistModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TherapistModel(
      therapistId: id,
      bio: data['bio'] ?? '',
      nationalId: data['nationalid'] ?? '',
      nationalProof: data['nationalproof'] ?? '',
      therapistImage: data['therapistimage'] ?? '',
      status: data['status'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bio': bio,
      'nationalid': nationalId,
      'nationalproof': nationalProof,
      'therapistimage': therapistImage,
      'status': status,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'therapistId': therapistId,
      'bio': bio,
      'nationalId': nationalId,
      'nationalProof': nationalProof,
      'therapistImage': therapistImage,
      'status': status,
    };
  }
}
