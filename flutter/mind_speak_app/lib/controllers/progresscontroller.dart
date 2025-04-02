import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/progressquestionrepository.dart';
import 'package:mind_speak_app/models/progressquestion.dart';
  
class ProgressController with ChangeNotifier {
  final ProgressRepository _repository;
  List<ProgressModel> _progressList = [];
  bool _isLoading = false;

  ProgressController(this._repository) {
    fetchProgress(); // Fetch data when the controller is created
  }

  List<ProgressModel> get progressList => _progressList;
  bool get isLoading => _isLoading;

  Future<void> fetchProgress() async {
    _isLoading = true;
    notifyListeners();
    try {
      _progressList = await _repository.getAllProgress();
    } catch (e) {
      print('Error fetching progress: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProgress(String question, String difficulty) async {
    final newProgress = ProgressModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      question: question,
      difficulty: difficulty,
    );
    await _repository.createProgress(newProgress);
    await fetchProgress();
  }

  Future<void> updateProgress(ProgressModel progress) async {
    await _repository.updateProgress(progress);
    await fetchProgress();
  }

  Future<void> deleteProgress(String id) async {
    await _repository.deleteProgress(id);
    await fetchProgress();
  }
}