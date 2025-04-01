import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/Repositories/ViewTherapistRepository.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class ViewTherapistController {
  final ITherapistRepository _therapistRepository;
  List<Map<String, dynamic>> allTherapistData = [];
  List<Map<String, dynamic>> filteredTherapistData = [];
  bool isLoading = true;

  ViewTherapistController({ITherapistRepository? repository})
      : _therapistRepository = repository ?? ViewTherapistRepository();

  Future<void> fetchApprovedTherapists(Function updateUI) async {
    try {
      isLoading = true;
      updateUI();

      allTherapistData = await _therapistRepository.fetchApprovedTherapists();
      filteredTherapistData = allTherapistData;
    } catch (e) {
      debugPrint('Error fetching therapists: $e');
    } finally {
      isLoading = false;
      updateUI();
    }
  }

  void searchTherapists(String query, Function updateUI) {
    if (query.isEmpty) {
      filteredTherapistData = allTherapistData;
    } else {
      filteredTherapistData = allTherapistData.where((data) {
        UserModel? user = data['user'];
        return user != null &&
            (user.username.toLowerCase().contains(query.toLowerCase()));
      }).toList();
    }
    updateUI();
  }

  Map<String, dynamic> therapistToMap(Map<String, dynamic> data) {
    TherapistModel therapist = data['therapist'];
    UserModel? user = data['user'];

    return {
      'id': therapist.therapistId,
      'name': user?.username ?? 'N/A',
      'email': user?.email ?? 'N/A',
      'phoneNumber': user?.phoneNumber.toString() ?? 'N/A',
      'nationalid': therapist.nationalId,
      'bio': therapist.bio,
      'therapistImage': therapist.therapistImage,
      'nationalProof': therapist.nationalProof,
    };
  }

  // Helper method to get display-friendly therapist information
  String getTherapistName(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      UserModel? user = filteredTherapistData[index]['user'];
      return user?.username ?? 'Unknown';
    }
    return 'Unknown';
  }

  String getTherapistEmail(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      UserModel? user = filteredTherapistData[index]['user'];
      return user?.email ?? 'No email';
    }
    return 'No email';
  }

  String getTherapistPhoneNumber(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      UserModel? user = filteredTherapistData[index]['user'];
      return user?.phoneNumber.toString() ?? 'No phone number';
    }
    return 'No phone number';
  }

  String getTherapistBio(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      TherapistModel therapist = filteredTherapistData[index]['therapist'];
      return therapist.bio;
    }
    return '';
  }

  String getTherapistImage(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      TherapistModel therapist = filteredTherapistData[index]['therapist'];
      return therapist.therapistImage;
    }
    return '';
  }

  TherapistModel? getTherapist(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      return filteredTherapistData[index]['therapist'];
    }
    return null;
  }

  UserModel? getUser(int index) {
    if (index >= 0 && index < filteredTherapistData.length) {
      return filteredTherapistData[index]['user'];
    }
    return null;
  }
}
