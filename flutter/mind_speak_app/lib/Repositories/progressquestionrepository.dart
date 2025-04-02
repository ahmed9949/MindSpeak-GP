import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/models/progressquestion.dart';
 
abstract class ProgressRepository {
  Future<List<ProgressModel>> getAllProgress();
  Future<void> createProgress(ProgressModel progress);
  Future<void> updateProgress(ProgressModel progress);
  Future<void> deleteProgress(String id);
}

class FirebaseProgressRepository implements ProgressRepository {
  final CollectionReference _progressCollection =
      FirebaseFirestore.instance.collection('progress');

  @override
  Future<List<ProgressModel>> getAllProgress() async {
    try {
      final querySnapshot = await _progressCollection.get();
      return querySnapshot.docs
          .map((doc) => ProgressModel.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      throw Exception('Error fetching progress: $e');
    }
  }

  @override
  Future<void> createProgress(ProgressModel progress) async {
    try {
      await _progressCollection.doc(progress.id).set(progress.toJson());
    } catch (e) {
      throw Exception('Error creating progress: $e');
    }
  }

  @override
  Future<void> updateProgress(ProgressModel progress) async {
    try {
      await _progressCollection.doc(progress.id).update(progress.toJson());
    } catch (e) {
      throw Exception('Error updating progress: $e');
    }
  }

  @override
  Future<void> deleteProgress(String id) async {
    try {
      await _progressCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting progress: $e');
    }
  }
}