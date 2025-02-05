import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:mind_speak_app/Repositories/ProfileRepository.dart';

class ProfileController {
  final ProfileRepository _repository;
  final ImagePicker _imagePicker;

  String? parentId;
  Map<String, dynamic>? parentData;
  List<Map<String, dynamic>> childrenData = [];
  List<Map<String, dynamic>> carsData = [];

  ProfileController({
    ProfileRepository? repository,
    ImagePicker? imagePicker,
  })  : _repository = repository ?? ProfileRepository(),
        _imagePicker = imagePicker ?? ImagePicker();

  Future<void> fetchParentAndChildData(String userId) async {
    try {
      // Fetch parent data
      parentData = await _repository.getParentData(userId);
      parentId = userId;

      // Fetch children data
      final childDocs = await _repository.getChildrenData(userId);

      List<Map<String, dynamic>> childrenWithDetails = [];
      List<Map<String, dynamic>> allCarsData = [];

      for (var childDoc in childDocs) {
        final childData = childDoc.data() as Map<String, dynamic>;
        final childId = childDoc.id;

        // Get therapist name
        String therapistName = await _getTherapistName(childData);
        childData['therapistName'] = therapistName;

        childrenWithDetails.add({...childData, 'id': childId});

        // Fetch CARS forms
        final carsDocs = await _repository.getCarsForms(childId);
        int trialNumber = 1;

        for (var carsDoc in carsDocs) {
          final carsData = carsDoc.data() as Map<String, dynamic>;
          allCarsData.add({
            'id': carsDoc.id,
            'childId': carsData['childId'] ?? 'Unknown',
            'trial': trialNumber++,
            'totalScore': carsData['totalScore'] ?? 'N/A',
            'selectedQuestions': carsData['selectedQuestions'] ?? [],
            'status': carsData['status'] ?? 'Unknown',
          });
        }
      }

      childrenData = childrenWithDetails;
      carsData = allCarsData;
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  Future<String> _getTherapistName(Map<String, dynamic> childData) async {
    if (childData['assigned'] != true || childData['therapistId'] == null) {
      return 'Not Assigned';
    }

    try {
      final therapistData =
          await _repository.getTherapistData(childData['therapistId']);

      if (therapistData == null) {
        return 'Unknown Therapist';
      }

      final userIdOfTherapist = therapistData['userid'];
      if (userIdOfTherapist == null) {
        return 'Unknown Therapist';
      }

      final userData = await _repository.getUserData(userIdOfTherapist);
      if (userData == null) {
        return 'Unknown Therapist';
      }

      return userData['username'] ?? 'N/A';
    } catch (e) {
      return 'Unknown Therapist';
    }
  }

  Future<void> updateChild(
      String childId, Map<String, dynamic> updatedData) async {
    await _repository.updateChild(childId, updatedData);
  }

  Future<void> updateChildPhoto(String childId) async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File file = File(pickedFile.path);
    final imageUrl = await _repository.uploadChildPhoto(childId, file);
    await updateChild(childId, {'childPhoto': imageUrl});
  }

  Future<void> deleteParentAccount(String userId) async {
    await _repository.deleteParentAccount(userId);
  }

  bool isValidAge(String age) {
    final parsedAge = int.tryParse(age);
    return parsedAge != null && parsedAge >= 3 && parsedAge <= 12;
  }
}
