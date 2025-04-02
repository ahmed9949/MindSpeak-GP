import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/SearchRepository.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class SearchPageController {
  final ISearchRepository _repository;
  final SearchRepository _searchRepository;

  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<List<TherapistModel>> therapistsNotifier =
      ValueNotifier<List<TherapistModel>>([]);
  final ValueNotifier<List<TherapistModel>> filteredTherapistsNotifier =
      ValueNotifier<List<TherapistModel>>([]);

  // Map to store user information for each therapist
  final Map<String, UserModel> _userInfoMap = {};

  List<TherapistModel> _therapists = [];

  SearchPageController({ISearchRepository? repository})
      : _repository = repository ?? SearchRepository(),
        _searchRepository =
            repository as SearchRepository? ?? SearchRepository();

  void init() {
    fetchTherapists();
  }

  void dispose() {
    loadingNotifier.dispose();
    therapistsNotifier.dispose();
    filteredTherapistsNotifier.dispose();
  }

  Future<void> fetchTherapists() async {
    try {
      loadingNotifier.value = true;

      // Get therapists from repository
      _therapists = await _repository.getTherapists();
      _userInfoMap.clear();

      // For each therapist, fetch associated user information
      // Since therapistId is the same as userId, we can directly fetch user info
      for (var therapist in _therapists) {
        try {
          final userInfo =
              await _repository.getTherapistUserInfo(therapist.therapistId);
          if (userInfo != null) {
            _userInfoMap[therapist.therapistId] = userInfo;
            print(
                'Successfully loaded user info for therapist: ${therapist.therapistId}');
            print('Username: ${userInfo.username}, Email: ${userInfo.email}');
          } else {
            print('No user info found for therapist: ${therapist.therapistId}');
          }
        } catch (e) {
          print(
              'Error fetching user info for therapist ${therapist.therapistId}: $e');
        }
      }

      therapistsNotifier.value = List.from(_therapists);
      filteredTherapistsNotifier.value = List.from(_therapists);

      print('Fetched ${_therapists.length} therapists successfully.');
      print('Retrieved user info for ${_userInfoMap.length} therapists.');
    } catch (e) {
      print('Error fetching therapists: $e');
    } finally {
      loadingNotifier.value = false;
    }
  }

  // Get user info for a specific therapist
  UserModel? getUserForTherapist(String therapistId) {
    UserModel? userInfo = _userInfoMap[therapistId];
    if (userInfo == null) {
      print('No cached user info for therapist: $therapistId');
    }
    return userInfo;
  }

  // Fetch user info on-demand if not available
  Future<UserModel?> fetchUserForTherapist(String therapistId) async {
    try {
      UserModel? userInfo = _userInfoMap[therapistId];
      if (userInfo != null) {
        return userInfo;
      }

      // Fetch user info if not already cached
      userInfo = await _repository.getTherapistUserInfo(therapistId);
      if (userInfo != null) {
        _userInfoMap[therapistId] = userInfo;
      }
      return userInfo;
    } catch (e) {
      print('Error fetching user info for therapist $therapistId: $e');
      return null;
    }
  }

  void searchTherapists(String query) {
    if (query.isEmpty) {
      filteredTherapistsNotifier.value = List.from(_therapists);
      return;
    }

    final filtered = _therapists.where((therapist) {
      // Get the associated user to access username
      UserModel? user = _userInfoMap[therapist.therapistId];
      if (user != null) {
        return user.username.toLowerCase().contains(query.toLowerCase());
      }
      return false;
    }).toList();

    filteredTherapistsNotifier.value = filtered;
  }

  Future<String> assignTherapistToChild(
      String therapistId, String? userId) async {
    if (userId == null || userId.isEmpty) {
      return 'No logged-in user.';
    }
    try {
      return await _repository.assignTherapistToChild(therapistId, userId);
    } catch (e) {
      print('Error assigning therapist: $e');
      return 'Failed to assign therapist: ${e.toString()}';
    }
  }
}
