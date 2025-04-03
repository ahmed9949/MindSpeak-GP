class TherapistModel {
  final String therapistId; // This is the document ID
  final String userId; // This links to the users collection
  final String bio;
  final String nationalId;
  final String nationalProof;
  final String therapistImage;
  final bool status;

  TherapistModel({
    required this.therapistId,
    required this.userId,
    required this.bio,
    required this.nationalId,
    required this.nationalProof,
    required this.therapistImage,
    this.status = false,
  });

  factory TherapistModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TherapistModel(
      therapistId: id,
      userId: data['userId'] ?? '',
      bio: data['bio'] ?? '',
      nationalId: data['nationalid'] ?? '',
      nationalProof: data['nationalproof'] ?? '',
      therapistImage: data['therapistimage'] ?? '',
      status: data['status'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'therapistId': therapistId,
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
      'userId': userId,
      'bio': bio,
      'nationalId': nationalId,
      'nationalProof': nationalProof,
      'therapistImage': therapistImage,
      'status': status,
    };
  }
}
