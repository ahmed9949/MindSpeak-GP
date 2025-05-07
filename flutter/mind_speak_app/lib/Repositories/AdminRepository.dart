import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

abstract class IAdminRepository {
  Future<int> getUsersCount();
  Future<int> getTherapistsCount();
  Future<List<Map<String, dynamic>>> getPendingTherapistRequests();
  Future<bool> approveTherapist(String therapistId);
  Future<bool> rejectTherapist(String therapistId);
  Future<void> deleteUserFromAuth(String email);
}

class AdminRepository implements IAdminRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  @override
  Future<int> getUsersCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error fetching users count: $e');
      return 0;
    }
  }

  @override
  Future<int> getTherapistsCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('therapist').get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error fetching therapists count: $e');
      return 0;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTherapistRequests() async {
    try {
      QuerySnapshot therapistSnapshot = await _firestore
          .collection('therapist')
          .where('status', isEqualTo: false)
          .get();

      if (therapistSnapshot.docs.isEmpty) return [];

      List<String> userIds =
          therapistSnapshot.docs.map((doc) => doc.id).toList();

      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      Map<String, UserModel> userMap = {
        for (var doc in userSnapshot.docs)
          doc.id: UserModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id)
      };

      return therapistSnapshot.docs.map((doc) {
        String id = doc.id;
        UserModel? user = userMap[id];
        TherapistModel therapist = TherapistModel.fromFirestore(
            doc.data() as Map<String, dynamic>, id);

        return {
          'therapist': therapist,
          'user': user,
          'therapistId': id,
          'bio': doc['bio'] ?? '',
          'nationalId': doc['nationalid'] ?? '',
          'nationalProof': doc['nationalproof'] ?? '',
          'therapistImage': doc['therapistimage'] ?? '',
          'therapistPhoneNumber': user?.phoneNumber ?? 0,
          'status': doc['status'] ?? false,
          'username': user?.username ?? '',
          'email': user?.email ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching therapist requests: $e');
      return [];
    }
  }

  @override
  Future<bool> approveTherapist(String therapistId) async {
    try {
      DocumentReference therapistRef =
          _firestore.collection('therapist').doc(therapistId);

      DocumentSnapshot therapistSnapshot = await therapistRef.get();
      if (!therapistSnapshot.exists) {
        debugPrint("Therapist document not found for id: $therapistId");
        return false;
      }

      DocumentReference userRef =
          _firestore.collection('users').doc(therapistId);

      DocumentSnapshot userSnapshot = await userRef.get();
      if (!userSnapshot.exists) {
        debugPrint("User document not found for id: $therapistId");
        return false;
      }

      WriteBatch batch = _firestore.batch();
      batch.update(therapistRef, {'status': true});
      batch.update(userRef, {'status': true});
      await batch.commit();

      return true;
    } catch (e) {
      debugPrint('Error approving therapist: $e');
      return false;
    }
  }

  @override
  Future<bool> rejectTherapist(String therapistId) async {
    try {
      // Step 1: Delete Firestore documents
      WriteBatch batch = _firestore.batch();

      DocumentReference therapistRef =
          _firestore.collection('therapist').doc(therapistId);
      DocumentReference userRef =
          _firestore.collection('users').doc(therapistId);

      batch.delete(therapistRef);
      batch.delete(userRef);

      await batch.commit();
      debugPrint('Therapist documents deleted from Firestore.');

      // Step 2: Delete from Firebase Authentication (if currently signed in)
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == therapistId) {
        try {
          await currentUser.delete();
          debugPrint('Therapist deleted from Firebase Authentication.');
        } catch (e) {
          debugPrint('Error deleting from Firebase Auth: $e');
        }
      } else {
        debugPrint('Therapist not currently signed in. Auth deletion skipped.');
      }

      return true;
    } catch (e) {
      debugPrint('Error rejecting therapist: $e');
      return false;
    }
  }

  @override
  Future<void> deleteUserFromAuth(String email) async {
    try {
      List<String> signInMethods =
          await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.isNotEmpty) {
        User? user = _auth.currentUser;

        if (user != null && user.email == email) {
          await user.delete();
          debugPrint('User deleted from Firebase Authentication.');
        } else {
          debugPrint(
              'User is not the currently signed-in user. Re-authentication needed.');
        }
      } else {
        debugPrint('This account is Rejected from the admin .');
      }
    } catch (e) {
      debugPrint('Error deleting user from Authentication: $e');
    }
  }
}
