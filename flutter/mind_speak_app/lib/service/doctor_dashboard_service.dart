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
          .collection('user')
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
}
