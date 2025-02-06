import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<int> getUsersCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('user').get();
      return snapshot.size;
    } catch (e) {
      debugPrint(' Error fetching users count: $e');
      return 0;
    }
  }

  Future<int> getTherapistsCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('therapist').get();
      return snapshot.size;
    } catch (e) {
      debugPrint(' Error fetching therapists count: $e');
      return 0;
    }
  }

  Future<List<TherapistModel>> getPendingTherapistRequests() async {
    try {
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: false)
          .get();

      if (therapistSnapshot.docs.isEmpty) return [];

      List<String> userIds =
          therapistSnapshot.docs.map((doc) => doc['userid'] as String).toList();

      QuerySnapshot userSnapshot = await _firestore
          .collection('user')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      Map<String, UserModel> userMap = {
        for (var doc in userSnapshot.docs)
          doc.id: UserModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          )
      };

      List<TherapistModel> therapists = therapistSnapshot.docs.map((doc) {
        String userId = doc['userid'] as String;
        UserModel? user = userMap[userId];

        return TherapistModel(
          therapistId: doc.id,
          userId: userId,
          bio: doc['bio'] ?? '',
          nationalId: doc['nationalid'] ?? '',
          nationalProof: doc['nationalproof'] ?? '',
          therapistImage: doc['therapistimage'] ?? '',
          therapistPhoneNumber: doc['therapistnumber'] ?? 0,
          status: doc['status'] ?? false,
          username: user?.username,
          email: user?.email,
        );
      }).toList();

      return therapists;
    } catch (e) {
      debugPrint('Error fetching therapist requests: $e');
      return [];
    }
  }

  Future<bool> approveTherapist(String therapistId) async {
    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference therapistRef =
          _firestore.collection('therapist').doc(therapistId);
      DocumentReference userRef =
          _firestore.collection('user').doc(therapistId);

      batch.update(therapistRef, {'status': true});
      batch.update(userRef, {'status': true});

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error approving therapist: $e');
      return false;
    }
  }

  Future<bool> rejectTherapist(String therapistId) async {
    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference therapistRef =
          _firestore.collection('therapist').doc(therapistId);
      DocumentReference userRef =
          _firestore.collection('user').doc(therapistId);

      batch.delete(therapistRef);
      batch.delete(userRef);

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error rejecting therapist: $e');
      return false;
    }
  }

  Future<void> deleteUserFromAuth(String email) async {
    try {
      List<String> signInMethods =
          await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.isNotEmpty) {
        User? user = _auth.currentUser;

        if (user != null && user.email == email) {
          await user.delete();
          debugPrint('Therapist deleted from Firebase Authentication.');
        } else {
          debugPrint(
              'Therapist is not the currently signed-in user. Re-authentication needed.');
        }
      } else {
        debugPrint('Therapist not found in Authentication.');
      }
    } catch (e) {
      debugPrint('Error deleting therapist from Authentication: $e');
    }
  }
}
