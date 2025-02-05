import 'package:cloud_firestore/cloud_firestore.dart';

class ViewDoctorRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  
  Future<List<Map<String, dynamic>>> fetchApprovedTherapists() async {
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

      List<List<String>> batches = [];
      const batchSize = 10;
      for (int i = 0; i < userIds.length; i += batchSize) {
        batches.add(userIds.sublist(i,
            i + batchSize > userIds.length ? userIds.length : i + batchSize));
      }

      List<DocumentSnapshot> allDocs = [];
      for (var batch in batches) {
        QuerySnapshot userSnapshot = await _firestore
            .collection('user')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        allDocs.addAll(userSnapshot.docs);
      }

      Map<String, Map<String, dynamic>> userMap = {
        for (var doc in allDocs) doc.id: doc.data() as Map<String, dynamic>
      };

      return therapistSnapshot.docs.map((doc) {
        var therapistData = doc.data() as Map<String, dynamic>;
        var userData = userMap[therapistData['userid']] ?? {};

        return {
          'id': doc.id,
          'name': userData['username'] ?? 'N/A',
          'email': userData['email'] ?? 'N/A',
          'nationalid': therapistData['nationalid'] ?? 'N/A',
          'bio': therapistData['bio'] ?? 'N/A',
          'therapistPhoneNumber':
              therapistData['therapistnumber']?.toString() ?? 'N/A',
          'therapistImage': therapistData['therapistimage'] ?? '',
          'nationalProof': therapistData['nationalproof'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Error fetching approved therapists: $e');
    }
  }
}
