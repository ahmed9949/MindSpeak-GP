import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

abstract class ISearchRepository {
  Future<List<TherapistModel>> getTherapists();
  Future<UserModel?> getTherapistUserInfo(String userId);
  Future<String> assignTherapistToChild(String therapistId, String userId);
}

class SearchRepository implements ISearchRepository {
  final FirebaseFirestore _firestore;

  SearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<TherapistModel>> getTherapists() async {
    try {
      final therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      List<TherapistModel> therapists = [];

      for (var doc in therapistSnapshot.docs) {
        var therapistData = doc.data();

        // Create TherapistModel directly from Firestore data
        TherapistModel therapist =
            TherapistModel.fromFirestore(therapistData, doc.id);
        therapists.add(therapist);
      }

      return therapists;
    } catch (e) {
      print('Error fetching therapists: $e');
      throw Exception('Failed to fetch therapists');
    }
  }

  @override
  Future<UserModel?> getTherapistUserInfo(String userId) async {
    try {
      // Since therapistId and userId are the same, we can use therapistId directly
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(
            userDoc.data() as Map<String, dynamic>, userId);
      }

      return null;
    } catch (e) {
      print('Error fetching user info: $e');
      return null;
    }
  }

  // Additional method to fetch therapist with associated user data simultaneously
  Future<Map<String, dynamic>> getTherapistWithUserInfo(
      String therapistId) async {
    try {
      final therapistDoc =
          await _firestore.collection('therapist').doc(therapistId).get();

      if (!therapistDoc.exists) {
        throw Exception('Therapist not found');
      }

      var therapistData = therapistDoc.data() as Map<String, dynamic>;

      // Since therapistId is the same as userId, we can use it directly
      String userId = therapistId;

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      TherapistModel therapist =
          TherapistModel.fromFirestore(therapistData, therapistId);
      UserModel user = UserModel.fromFirestore(
          userDoc.data() as Map<String, dynamic>, userId);

      return {
        'therapist': therapist,
        'user': user,
      };
    } catch (e) {
      print('Error fetching therapist with user info: $e');
      throw Exception('Failed to fetch therapist data');
    }
  }

  @override
  Future<String> assignTherapistToChild(
      String therapistId, String userId) async {
    try {
      // Check if therapist has maximum allowed children (3)
      final assignedChildrenSnapshot = await _firestore
          .collection('child')
          .where('therapistId', isEqualTo: therapistId)
          .where('assigned', isEqualTo: true)
          .get();

      if (assignedChildrenSnapshot.docs.length >= 3) {
        return 'This therapist already has the maximum number of children assigned.';
      }

      // Verify therapist exists
      final therapistDoc =
          await _firestore.collection('therapist').doc(therapistId).get();

      if (!therapistDoc.exists) {
        return 'Selected therapist does not exist.';
      }

      // Check if child record exists for this user
      final childQuery = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (childQuery.docs.isEmpty) {
        // Create new child record
        await _firestore.collection('child').add({
          'userId': userId,
          'therapistId': therapistId,
          'assigned': true,
        });
      } else {
        // Update existing child record
        await childQuery.docs.first.reference.update({
          'therapistId': therapistId,
          'assigned': true,
        });
      }

      return 'Therapist assigned successfully!';
    } catch (e) {
      print('Error assigning therapist: $e');
      return 'Failed to assign therapist.';
    }
  }
}
