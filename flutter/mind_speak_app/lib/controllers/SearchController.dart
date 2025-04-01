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
      // Based on the repository code, it seems like therapists have user information
      // stored in a separate collection
      for (var therapist in _therapists) {
        try {
          // Using the method that fetches therapist with user info in one go
          var combinedData = await _searchRepository
              .getTherapistWithUserInfo(therapist.therapistId);

          if (combinedData.containsKey('user')) {
            _userInfoMap[therapist.therapistId] =
                combinedData['user'] as UserModel;
          }
        } catch (e) {
          print(
              'Error fetching user info for therapist ${therapist.therapistId}: $e');

          // Fallback approach: try to get the user directly if available in Firestore
          try {
            // Using the new method in SearchRepository instead of direct _firestore access
            final userDoc = await _searchRepository
                .findUsersByTherapistId(therapist.therapistId);

            if (userDoc.docs.isNotEmpty) {
              final userId = userDoc.docs.first.id;
              final userInfo = await _repository.getTherapistUserInfo(userId);
              if (userInfo != null) {
                _userInfoMap[therapist.therapistId] = userInfo;
              }
            }
          } catch (innerError) {
            print('Secondary error fetching user: $innerError');
          }
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
    return _userInfoMap[therapistId];
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
