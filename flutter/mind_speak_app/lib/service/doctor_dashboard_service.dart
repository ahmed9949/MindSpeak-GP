import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class DoctorDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  

  Future<List<ChildModel>> fetchChildren(String therapistId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('child')
          .where('therapistId', isEqualTo: therapistId)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return ChildModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch children: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReport(String childId) async {
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

  Future<UserModel> getUserInfo(String userId) async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }

      Map<String, dynamic> data = userSnapshot.data() as Map<String, dynamic>;
      return UserModel.fromFirestore(data, userSnapshot.id);
    } catch (e) {
      throw Exception('Failed to fetch user info: $e');
    }
  }

  Future<TherapistModel> getTherapistInfo(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('therapist')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Therapist not found');
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return TherapistModel.fromFirestore(data, doc.id);
    } catch (e) {
      throw Exception('Failed to fetch therapist info: $e');
    }
  }

  Future<void> updateTherapistInfo(
      String therapistId, TherapistModel updatedTherapist) async {
    try {
      await _firestore
          .collection('therapist')
          .doc(therapistId)
          .update(updatedTherapist.toFirestore());
    } catch (e) {
      throw Exception('Failed to update therapist info: ${e.toString()}');
    }
  }

  Future<void> updateUserInfo(String userId, UserModel updatedUser) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update(updatedUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update user info: ${e.toString()}');
    }
  }

  Future<void> deleteAccount(String userId, String therapistId) async {
    try {
      // First update any associated children
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

      // Then delete the Firestore documents
      await _firestore.collection('users').doc(userId).delete();
      await _firestore.collection('therapist').doc(therapistId).delete();

      // Finally delete the Firebase Auth user
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<UserModel> refreshUserData(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) throw Exception('User not found');
    final data = snapshot.data() as Map<String, dynamic>;
    return UserModel.fromFirestore(data, snapshot.id);
  }

  Future<TherapistModel> refreshTherapistData(String therapistId) async {
    final snapshot =
        await _firestore.collection('therapist').doc(therapistId).get();
    if (!snapshot.exists) throw Exception('Therapist not found');
    final data = snapshot.data() as Map<String, dynamic>;
    return TherapistModel.fromFirestore(data, snapshot.id);
  }
}
