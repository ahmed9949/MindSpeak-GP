import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mind_speak_app/models/admin_state.dart';

class AdminController with ChangeNotifier {
  final IAdminRepository _repository;

  AdminState _state = const AdminState();
  static const int itemsPerPage = 5;

  AdminController({required IAdminRepository repository})
      : _repository = repository {
    _initializeData();
  }
  AdminState get state => _state;

  Future<void> _initializeData() async {
    await Future.wait([
      fetchCounts(),
      fetchTherapistRequests(),
    ]);
  }

  Future<void> fetchCounts() async {
    final userCount = await _repository.getUsersCount();
    final therapistCount = await _repository.getTherapistsCount();

    _state = _state.copyWith(
      userCount: userCount,
      therapistCount: therapistCount,
    );
    notifyListeners();
  }

  Future<void> fetchTherapistRequests() async {
    final therapistData = await _repository.getPendingTherapistRequests();
    final totalPages = (therapistData.length / itemsPerPage).ceil();
    final currentPage = _state.currentPage > totalPages
        ? (totalPages > 0 ? totalPages : 1)
        : _state.currentPage;

    _state = _state.copyWith(
      therapistData: therapistData,
      totalPages: totalPages,
      currentPage: currentPage,
    );
    notifyListeners();
  }

  Future<void> approveTherapist(
      BuildContext context, String therapistId) async {
    final success = await _repository.approveTherapist(therapistId);

    if (success) {
      final updatedTherapistData = _state.therapistData
          .where((data) => data['therapistId'] != therapistId)
          .toList();

      _updateTherapistsList(updatedTherapistData);
      _showMessage(context, 'Therapist approved successfully!', Colors.green);
    } else {
      _showMessage(context, 'Failed to approve therapist', Colors.red);
    }
  }

  Future<void> rejectTherapist(
    BuildContext context,
    String therapistId,
    String email,
  ) async {
    final success = await _repository.rejectTherapist(therapistId);

    if (success) {
      await _repository.deleteUserFromAuth(email);

      final updatedTherapistData = _state.therapistData
          .where((data) => data['therapistId'] != therapistId)
          .toList();

      _updateTherapistsList(updatedTherapistData);
      _showMessage(context, 'Therapist permanently deleted!', Colors.red);
    } else {
      _showMessage(context, 'Failed to delete therapist', Colors.red);
    }
  }

  void _updateTherapistsList(List<Map<String, dynamic>> updatedTherapistData) {
    final totalPages = (updatedTherapistData.length / itemsPerPage).ceil();
    final currentPage = _state.currentPage > totalPages
        ? (totalPages > 0 ? totalPages : 1)
        : _state.currentPage;

    _state = _state.copyWith(
      therapistData: updatedTherapistData,
      totalPages: totalPages,
      currentPage: currentPage,
    );
    notifyListeners();
  }

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void nextPage() {
    if (_state.currentPage < _state.totalPages) {
      _state = _state.copyWith(currentPage: _state.currentPage + 1);
      notifyListeners();
    }
  }

  void previousPage() {
    if (_state.currentPage > 1) {
      _state = _state.copyWith(currentPage: _state.currentPage - 1);
      notifyListeners();
    }
  }

  void toggleUsersCount() {
    _state = _state.copyWith(showUsersCount: !_state.showUsersCount);
    notifyListeners();
  }

  void toggleTherapistCount() {
    _state = _state.copyWith(showTherapistCount: !_state.showTherapistCount);
    notifyListeners();
  }
}
