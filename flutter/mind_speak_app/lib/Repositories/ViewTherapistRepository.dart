import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

abstract class ITherapistRepository {
  Future<List<Map<String, dynamic>>> fetchApprovedTherapists();
}

class ViewTherapistRepository implements ITherapistRepository {
  final FirebaseFirestore _firestore;

  ViewTherapistRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  @override
  Future<List<Map<String, dynamic>>> fetchApprovedTherapists() async {
    try {
      // Fetch approved therapists
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      // Extract user IDs from therapist documents
      List<String> userIds = therapistSnapshot.docs
          .map((doc) => doc.id) // Use therapistId as userId
          .toList();
      if (userIds.isEmpty) {
        return therapistSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'therapist': TherapistModel.fromFirestore(data, doc.id),
            'user': null,
          };
        }).toList();
      }

      // Fetch user documents in batches
      List<DocumentSnapshot> userDocs =
          await _fetchUserDocumentsInBatches(userIds);

      // Create a map of user ID to user data
      Map<String, UserModel> userMap = {};
      for (var doc in userDocs) {
        userMap[doc.id] =
            UserModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }

      // Combine therapist and user data
      return therapistSnapshot.docs.map((doc) {
        var therapistData = doc.data() as Map<String, dynamic>;
        TherapistModel therapist =
            TherapistModel.fromFirestore(therapistData, doc.id);
        UserModel? user = userMap[doc.id];

        return {
          'therapist': therapist,
          'user': user,
        };
      }).toList();
    } catch (e) {
      debugPrint('Repository Error: $e');
      throw Exception('Error fetching approved therapists: $e');
    }
  }

  Future<List<DocumentSnapshot>> _fetchUserDocumentsInBatches(
      List<String> userIds) async {
    List<DocumentSnapshot> allDocs = [];
    const batchSize = 10;

    for (var i = 0; i < userIds.length; i += batchSize) {
      var batch = userIds.sublist(
          i, i + batchSize > userIds.length ? userIds.length : i + batchSize);

      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allDocs.addAll(userSnapshot.docs);
    }

    return allDocs;
  }
}
