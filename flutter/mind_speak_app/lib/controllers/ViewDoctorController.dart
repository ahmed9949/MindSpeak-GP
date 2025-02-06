import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/ViewDoctorRepository.dart';
import 'package:mind_speak_app/models/Therapist.dart';


class ViewDoctorController {
  final ITherapistRepository _doctorRepository;
  List<TherapistModel> allTherapists = [];
  List<TherapistModel> filteredTherapists = [];
  bool isLoading = true;

  ViewDoctorController({ITherapistRepository? repository})
      : _doctorRepository = repository ?? DoctorRepository();

  Future<void> fetchApprovedTherapists(Function updateUI) async {
    try {
      isLoading = true;
      updateUI();

      allTherapists = await _doctorRepository.fetchApprovedTherapists();
      filteredTherapists = allTherapists;
    } catch (e) {
      debugPrint('Error fetching therapists: $e');
    } finally {
      isLoading = false;
      updateUI();
    }
  }

  void searchTherapists(String query, Function updateUI) {
    if (query.isEmpty) {
      filteredTherapists = allTherapists;
    } else {
      filteredTherapists = allTherapists
          .where((therapist) =>
              therapist.username?.toLowerCase().contains(query.toLowerCase()) ??
              false)
          .toList();
    }
    updateUI();
  }

  Map<String, dynamic> therapistToMap(TherapistModel therapist) {
    return {
      'id': therapist.therapistId,
      'name': therapist.username ?? 'N/A',
      'email': therapist.email ?? 'N/A',
      'nationalid': therapist.nationalId,
      'bio': therapist.bio,
      'therapistPhoneNumber': therapist.therapistPhoneNumber.toString(),
      'therapistImage': therapist.therapistImage,
      'nationalProof': therapist.nationalProof,
    };
  }
}
