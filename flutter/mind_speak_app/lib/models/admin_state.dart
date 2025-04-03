import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class AdminState {
  final int userCount;
  final int therapistCount;
  final List<Map<String, dynamic>> therapistData;
  final int currentPage;
  final int totalPages;
  final bool showUsersCount;
  final bool showTherapistCount;

  const AdminState({
    this.userCount = 0,
    this.therapistCount = 0,
    this.therapistData = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.showUsersCount = true,
    this.showTherapistCount = true,
  });

  // Computed properties to get therapists and users from therapistData
  List<TherapistModel> get therapists => therapistData.map((data) {
        return TherapistModel(
          userId: data['userId'],
          therapistId: data['therapistId'],
          bio: data['bio'] ?? '',
          nationalId: data['nationalId'] ?? '',
          nationalProof: data['nationalProof'] ?? '',
          therapistImage: data['therapistImage'] ?? '',
          status: data['status'] ?? false,
        );
      }).toList();

  List<UserModel> get users => therapistData.map((data) {
        return UserModel(
          userId: data['therapistId'], // Use the same ID
          email: data['email'] ?? '',
          username: data['username'] ?? '',
          role: 'therapist',
          password:
              '', // Password isn't included in the data returned from repository
          phoneNumber: data['therapistPhoneNumber'] ?? 0,
        );
      }).toList();

  AdminState copyWith({
    int? userCount,
    int? therapistCount,
    List<Map<String, dynamic>>? therapistData,
    int? currentPage,
    int? totalPages,
    bool? showUsersCount,
    bool? showTherapistCount,
  }) {
    return AdminState(
      userCount: userCount ?? this.userCount,
      therapistCount: therapistCount ?? this.therapistCount,
      therapistData: therapistData ?? this.therapistData,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showUsersCount: showUsersCount ?? this.showUsersCount,
      showTherapistCount: showTherapistCount ?? this.showTherapistCount,
    );
  }
}
