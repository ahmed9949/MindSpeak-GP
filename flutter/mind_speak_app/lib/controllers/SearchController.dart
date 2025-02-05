import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/SearchRepository.dart';


class SearchPageController {
  final SearchRepository _repository;
  
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<List<Map<String, dynamic>>> therapistsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> filteredTherapistsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);

  List<Map<String, dynamic>> _therapists = [];

  SearchPageController({SearchRepository? repository})
      : _repository = repository ?? FirebaseSearchRepository();

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
            therapist['name'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<String> assignTherapistToChild(String therapistId, String? userId) async {
    if (userId == null) {
      return 'No logged-in user.';
    }
    return await _repository.assignTherapistToChild(therapistId, userId);
  }
}