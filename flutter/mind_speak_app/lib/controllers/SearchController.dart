import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/SearchRepository.dart';
import 'package:mind_speak_app/models/Therapist.dart';

class SearchPageController {
  final SearchRepository _repository;

  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<List<TherapistModel>> therapistsNotifier =
      ValueNotifier<List<TherapistModel>>([]);
  final ValueNotifier<List<TherapistModel>> filteredTherapistsNotifier =
      ValueNotifier<List<TherapistModel>>([]);

  List<TherapistModel> _therapists = [];

  SearchPageController({SearchRepository? repository})
      : _repository = repository ?? SearchRepository();

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
      _therapists = await _repository.getTherapists();

      therapistsNotifier.value = _therapists;
      filteredTherapistsNotifier.value = _therapists;

      print('Fetched ${_therapists.length} therapists successfully.');
    } catch (e) {
      print('Error fetching therapists: $e');
    } finally {
      loadingNotifier.value = false;
    }
  }

  void searchTherapists(String query) {
    filteredTherapistsNotifier.value = _therapists
        .where((therapist) =>
            therapist.username!.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<String> assignTherapistToChild(
      String therapistId, String? userId) async {
    if (userId == null) {
      return 'No logged-in user.';
    }
    return await _repository.assignTherapistToChild(therapistId, userId);
  }
}
