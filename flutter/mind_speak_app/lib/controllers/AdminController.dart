import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';

class AdminController with ChangeNotifier {
  final AdminRepository _adminRepository = AdminRepository();

  int userCount = 0;
  int therapistCount = 0;
  List<Map<String, dynamic>> therapists = [];

  int currentPage = 1;
  int itemsPerPage = 5;
  int totalPages = 1;

  bool showUsersCount = false;
  bool showTherapistCount = false;

  AdminController() {
    fetchCounts();
    fetchTherapistRequests();
  }

  Future<void> fetchCounts() async {
    userCount = await _adminRepository.getUsersCount();
    therapistCount = await _adminRepository.getTherapistsCount();
  }

  Future<void> fetchTherapistRequests() async {
    therapists = await _adminRepository.getPendingTherapistRequests();
    totalPages = (therapists.length / itemsPerPage).ceil();
    if (currentPage > totalPages) {
      currentPage = totalPages > 0 ? totalPages : 1;
    }
    notifyListeners();
  }

  Future<void> approveTherapist(
      BuildContext context, String therapistId) async {
    bool success = await _adminRepository.approveTherapist(therapistId);
    if (success) {
      therapists.removeWhere((therapist) => therapist['userid'] == therapistId);
      totalPages = (therapists.length / itemsPerPage).ceil();
      if (currentPage > totalPages) {
        currentPage = totalPages > 0 ? totalPages : 1;
      }
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Therapist approved successfully!'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to approve therapist'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> rejectTherapist(
      BuildContext context, String therapistId, String email) async {
    bool success = await _adminRepository.rejectTherapist(therapistId, email);

    if (success) {
      therapists.removeWhere((therapist) => therapist['userid'] == therapistId);
      totalPages = (therapists.length / itemsPerPage).ceil();
      if (currentPage > totalPages) {
        currentPage = totalPages > 0 ? totalPages : 1;
      }
      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Therapist permanently deleted!'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete therapist'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void nextPage() {
    if (currentPage < totalPages) {
      currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      currentPage--;
      notifyListeners();
    }
  }

  void toggleUsersCount() {
    showUsersCount = !showUsersCount;
    notifyListeners();
  }

  void toggleTherapistCount() {
    showTherapistCount = !showTherapistCount;
    notifyListeners();
  }
}
