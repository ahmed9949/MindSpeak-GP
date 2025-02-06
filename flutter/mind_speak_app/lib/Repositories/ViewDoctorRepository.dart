import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/models/Therapist.dart';


abstract class ITherapistRepository {
  Future<List<TherapistModel>> fetchApprovedTherapists();
}

class DoctorRepository implements ITherapistRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<TherapistModel>> fetchApprovedTherapists() async {
    try {
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      List<String> userIds = therapistSnapshot.docs
          .map((doc) => doc['userid'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (userIds.isEmpty) return [];

      List<DocumentSnapshot> userDocs =
          await _fetchUserDocumentsInBatches(userIds);
      Map<String, Map<String, dynamic>> userMap = _createUserMap(userDocs);

      return _combineTherapistAndUserData(therapistSnapshot.docs, userMap);
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
          .collection('user')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allDocs.addAll(userSnapshot.docs);
    }

    return allDocs;
  }

  Map<String, Map<String, dynamic>> _createUserMap(
      List<DocumentSnapshot> docs) {
    return {for (var doc in docs) doc.id: doc.data() as Map<String, dynamic>};
  }

  List<TherapistModel> _combineTherapistAndUserData(
      List<QueryDocumentSnapshot> therapistDocs,
      Map<String, Map<String, dynamic>> userMap) {
    return therapistDocs.map((doc) {
      var therapistData = doc.data() as Map<String, dynamic>;
      var userData = userMap[therapistData['userid']] ?? {};

      return TherapistModel(
        therapistId: doc.id,
        userId: therapistData['userid'] ?? '',
        bio: therapistData['bio'] ?? '',
        nationalId: therapistData['nationalid'] ?? '',
        nationalProof: therapistData['nationalproof'] ?? '',
        therapistImage: therapistData['therapistimage'] ?? '',
        therapistPhoneNumber: therapistData['therapistnumber'] ?? 0,
        status: therapistData['status'] ?? false,
        username: userData['username'],
        email: userData['email'],
      );
    }).toList();
  }
}
