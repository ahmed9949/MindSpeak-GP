import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/ViewDoctorRepository.dart';

class ViewDoctorsController {
  final DoctorRepository _doctorRepository = DoctorRepository();
  
  List<Map<String, dynamic>> allTherapists = [];
  List<Map<String, dynamic>> filteredTherapists = [];
  bool isLoading = true;

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
              therapist["name"].toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    updateUI();
  }
}
