class TherapistModel {
  final String therapistId;
  final String userId;
  final String bio;
  final String nationalId;
  final String nationalProof;
  final String therapistImage;
  final int therapistPhoneNumber;
  final bool status;
  final String? username; // Added from UserModel
  final String? email; // Added from UserModel

  TherapistModel({
    required this.therapistId,
    required this.userId,
    required this.bio,
    required this.nationalId,
    required this.nationalProof,
    required this.therapistImage,
    required this.therapistPhoneNumber,
    this.status = false,
    this.username,
    this.email,
  });

  factory TherapistModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TherapistModel(
      therapistId: id,
      userId: data['userid'] ?? '',
      bio: data['bio'] ?? '',
      nationalId: data['nationalid'] ?? '',
      nationalProof: data['nationalproof'] ?? '',
      therapistImage: data['therapistimage'] ?? '',
      therapistPhoneNumber: data['therapistnumber'] ?? 0,
      status: data['status'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userid': userId,
      'bio': bio,
      'nationalid': nationalId,
      'nationalproof': nationalProof,
      'therapistimage': therapistImage,
      'therapistnumber': therapistPhoneNumber,
      'status': status,
    };
  }

  TherapistModel copyWith({
    String? therapistId,
    String? userId,
    String? bio,
    String? nationalId,
    String? nationalProof,
    String? therapistImage,
    int? therapistPhoneNumber,
    bool? status,
    String? username,
    String? email,
  }) {
    return TherapistModel(
      therapistId: therapistId ?? this.therapistId,
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      nationalId: nationalId ?? this.nationalId,
      nationalProof: nationalProof ?? this.nationalProof,
      therapistImage: therapistImage ?? this.therapistImage,
      therapistPhoneNumber: therapistPhoneNumber ?? this.therapistPhoneNumber,
      status: status ?? this.status,
      username: username ?? this.username,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TherapistModel &&
          runtimeType == other.runtimeType &&
          therapistId == other.therapistId &&
          userId == other.userId;

  @override
  int get hashCode => therapistId.hashCode ^ userId.hashCode;

  bool get isApproved => status;
}
