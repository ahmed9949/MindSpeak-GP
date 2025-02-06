import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class AdminState {
  final int userCount;
  final int therapistCount;
  final List<TherapistModel> therapists;
  final List<UserModel> users;
  final int currentPage;
  final int totalPages;
  final bool showUsersCount;
  final bool showTherapistCount;

  const AdminState({
    this.userCount = 0,
    this.therapistCount = 0,
    this.therapists = const [],
    this.users = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.showUsersCount = false,
    this.showTherapistCount = false,
  });

  AdminState copyWith({
    int? userCount,
    int? therapistCount,
    List<TherapistModel>? therapists,
    List<UserModel>? users,
    int? currentPage,
    int? totalPages,
    bool? showUsersCount,
    bool? showTherapistCount,
  }) {
    return AdminState(
      userCount: userCount ?? this.userCount,
      therapistCount: therapistCount ?? this.therapistCount,
      therapists: therapists ?? this.therapists,
      users: users ?? this.users,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showUsersCount: showUsersCount ?? this.showUsersCount,
      showTherapistCount: showTherapistCount ?? this.showTherapistCount,
    );
  }
}
