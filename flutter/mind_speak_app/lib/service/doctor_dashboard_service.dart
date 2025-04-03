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

  // Space

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

  Future<Map<String, dynamic>> getTherapistInfo(String therapistId) async {
    try {
      DocumentSnapshot therapistSnapshot = await FirebaseFirestore.instance
          .collection('therapist')
          .doc(therapistId)
          .get();
      if (!therapistSnapshot.exists) {
        throw Exception('Therapist not found');
      }
      return therapistSnapshot.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch therapist info: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String therapistId) async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(therapistId)
          .get();
      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }
      return userSnapshot.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch therapist info: ${e.toString()}');
    }
  }

  // Update functions
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
}
