// search_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class SearchRepository {
  Future<List<Map<String, dynamic>>> getTherapists();
  Future<String> assignTherapistToChild(String therapistId, String userId);
}

class FirebaseSearchRepository implements SearchRepository {
  final FirebaseFirestore _firestore;

  FirebaseSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> getTherapists() async {
    try {
      final therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> therapists = [];

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

          therapists.add({
            'therapistId': doc.id,
            'name': userData['username'] ?? 'Unknown',
            'email': userData['email'] ?? 'N/A',
            'therapistPhoneNumber':
                therapistData['therapistnumber']?.toString() ?? 'N/A',
            'bio': therapistData['bio'] ?? 'N/A',
            'therapistImage': therapistData['therapistimage'] ?? '',
          });
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
      // Check therapist's current assigned children
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

      // Check and update child document
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
