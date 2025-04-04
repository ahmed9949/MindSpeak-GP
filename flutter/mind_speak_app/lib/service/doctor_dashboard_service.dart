import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchChildren(String sessionId) async {
    try {
      return await getAllChildren(sessionId);
    } catch (e) {
      throw Exception('Error fetching children: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReport(String childId) async {
    try {
      return await fetchReportsForChild(childId);
    } catch (e) {
      throw Exception('Error fetching reports: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllChildren(String therapistId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('child')
          .where('therapistId', isEqualTo: therapistId)
          .get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch children: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportsForChild(
      String childId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reports')
          .where('childId', isEqualTo: childId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reports for child: $e');
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }

      final data = userSnapshot.data() as Map<String, dynamic>;
      data['userid'] = userSnapshot.id;
      return data;
    } catch (e) {
      throw Exception('Failed to fetch user info: $e');
    }
  }

  Future<Map<String, dynamic>> getTherapistInfoByUserId(String userId) async {
    final snapshot = await _firestore
        .collection('therapist')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Therapist not found');
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['therapistid'] = doc.id;
    return data;
  }

  Future<void> updateTherapistInfo(
      String therapistId, Map<String, dynamic> updatedInfo) async {
    try {
      await _firestore
          .collection('therapist')
          .doc(therapistId)
          .update(updatedInfo);
    } catch (e) {
      throw Exception('Failed to update therapist info: ${e.toString()}');
    }
  }

  Future<void> updateUserInfo(
      String userId, Map<String, dynamic> updatedInfo) async {
    try {
      await _firestore.collection('users').doc(userId).update(updatedInfo);
    } catch (e) {
      throw Exception('Failed to update user info: ${e.toString()}');
    }
  }

  Future<void> deleteAccount(String userId, String therapistId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      await _firestore.collection('therapist').doc(therapistId).delete();

      await _firestore
          .collection('child')
          .where('therapistId', isEqualTo: therapistId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({
            'therapistId': "",
            'assigned': false,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<Map<String, dynamic>> refreshUserData(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) throw Exception('User not found');
    final data = snapshot.data() as Map<String, dynamic>;
    data['userid'] = snapshot.id;
    return data;
  }

  Future<Map<String, dynamic>> refreshTherapistData(String therapistId) async {
    final snapshot =
        await _firestore.collection('therapist').doc(therapistId).get();
    if (!snapshot.exists) throw Exception('Therapist not found');
    final data = snapshot.data() as Map<String, dynamic>;
    data['therapistid'] = snapshot.id;
    return data;
  }
}
