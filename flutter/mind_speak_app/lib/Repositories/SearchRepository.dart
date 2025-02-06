import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/models/Therapist.dart';


abstract class ISearchRepository {
  Future<List<TherapistModel>> getTherapists();
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

        if (therapistData['userid'] == null ||
            therapistData['userid'].toString().isEmpty) {
          print('Skipping therapist document with invalid userid: ${doc.id}');
          continue;
        }

        final userDoc = await _firestore
            .collection('user')
            .doc(therapistData['userid'])
            .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;

          therapists.add(TherapistModel(
            therapistId: doc.id,
            userId: therapistData['userid'],
            bio: therapistData['bio'] ?? '',
            nationalId: therapistData['nationalid'] ?? '',
            nationalProof: therapistData['nationalproof'] ?? '',
            therapistImage: therapistData['therapistimage'] ?? '',
            therapistPhoneNumber: therapistData['therapistnumber'] ?? 0,
            status: therapistData['status'] ?? false,
            username: userData['username'],
            email: userData['email'],
          ));
        }
      }

      return therapists;
    } catch (e) {
      print('Error fetching therapists: $e');
      throw Exception('Failed to fetch therapists');
    }
  }

  @override
  Future<String> assignTherapistToChild(
      String therapistId, String userId) async {
    try {
      
      final assignedChildrenSnapshot = await _firestore
          .collection('child')
          .where('therapistId', isEqualTo: therapistId)
          .where('assigned', isEqualTo: true)
          .get();

      if (assignedChildrenSnapshot.docs.length >= 3) {
        return 'This therapist already has the maximum number of children assigned.';
      }

      
      final therapistDoc =
          await _firestore.collection('therapist').doc(therapistId).get();

      if (!therapistDoc.exists) {
        return 'Selected therapist does not exist.';
      }

     
      final childQuery = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (childQuery.docs.isEmpty) {
        await _firestore.collection('child').add({
          'userId': userId,
          'therapistId': therapistId,
          'assigned': true,
        });
      } else {
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
