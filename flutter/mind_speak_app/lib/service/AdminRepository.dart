import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // get all the number of users
  Future<int> getUsersCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('user').get();
      return snapshot.size;
    } catch (e) {
      throw Exception('Failed to fetch users count $e');
    }
  }

  // get all the number of therapists
  Future<int> getTherapistsCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('therapist').get();
      return snapshot.size;
    } catch (e) {
      throw Exception('Failed to fetch therapists count $e');
    }
  }

  // get therapist requests
  Future<List<Map<String, dynamic>>> getPendingTherapistRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> therapists = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DocumentSnapshot userDoc =
            await _firestore.collection('user').doc(data['userid']).get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          therapists.add({
            'username': userData['username'] ?? 'N/A',
            'email': userData['email'] ?? 'N/A',
            'nationalid': data['nationalid'] ?? 'N/A',
            'bio': data['bio'] ?? 'N/A',
            'therapistPhoneNumber':
                data['therapistnumber']?.toString() ?? 'N/A',
            'nationalProof': data['nationalproof'] ?? '',
            'therapistImage': data['therapistimage'] ?? '',
            'userid': doc.id,
          });
        }
      }
      return therapists;
    } catch (e) {
      throw Exception('Failed to fetch therapist requests: $e');
    }
  }

  // approve therapist request
  Future<void> approveTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapist').doc(therapistId).update({
        'status': true,
      });
      await _firestore.collection('user').doc(therapistId).update({
        'status': true,
      });
    } catch (e) {
      throw Exception('Failed to approve therapist: $e');
    }
  }

  // Reject a therapist
  Future<void> rejectTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapist').doc(therapistId).delete();
      await _firestore.collection('user').doc(therapistId).delete();
    } catch (e) {
      throw Exception('Failed to reject therapist: $e');
    }
  }
}
