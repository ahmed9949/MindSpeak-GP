import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mind_speak_app/Repositories/ProfileRepository.dart';
import 'package:mind_speak_app/models/User.dart';

class ProfileController {
  final ProfileRepository _repository;
  final ImagePicker _imagePicker;

  String? parentId;
  // Store the parent model (UserModel) internally.
  UserModel? _parentDataModel;
  // Expose parent data to the UI as a Map using toFirestore().
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
      // Fetch parent data as a UserModel.
      _parentDataModel = await _repository.getParentData(userId);
      parentId = userId;
      // Convert the UserModel to a Map for the UI.
      parentData = _parentDataModel?.toFirestore();

      // Fetch children data (List<ChildModel>).
      final childModels = await _repository.getChildrenData(userId);
      List<Map<String, dynamic>> childrenWithDetails = [];
      List<Map<String, dynamic>> allCarsData = [];

      for (var childModel in childModels) {
        // Convert ChildModel to a map.
        final childData = childModel.toFirestore();
        final childId = childModel.childId;

        // Get therapist name using child data.
        String therapistName = await _getTherapistName(childData);
        childData['therapistName'] = therapistName;

        childrenWithDetails.add({...childData, 'id': childId});

        // Fetch CARS forms (List<CarsFormModel>) for this child.
        final carsModels = await _repository.getCarsForms(childId);
        int trialNumber = 1;
        for (var carsModel in carsModels) {
          allCarsData.add({
            'id': carsModel.formId,
            'childId': carsModel.childId,
            'trial': trialNumber++,
            'totalScore': carsModel.totalScore, // This is a double.
            'selectedQuestions': carsModel.selectedQuestions,
            'status': carsModel.status,
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
    if (childData['assigned'] != true ||
        childData['therapistId'] == null ||
        childData['therapistId'] == '') {
      return 'Not Assigned';
    }
    try {
      final therapistModel =
          await _repository.getTherapistData(childData['therapistId']);
      if (therapistModel == null) {
        return 'Unknown Therapist';
      }

      final userModel =
          await _repository.getUserData(therapistModel.therapistId);
      if (userModel == null) {
        return 'Unknown Therapist';
      }
      return userModel.username;
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
