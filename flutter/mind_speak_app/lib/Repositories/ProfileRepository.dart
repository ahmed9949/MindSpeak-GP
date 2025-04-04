import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mind_speak_app/models/CarsFrom.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'dart:io';

import 'package:mind_speak_app/models/User.dart';

abstract class IProfileRepository {
  /// Fetch the parent data as a UserModel.
  Future<UserModel> getParentData(String userId);

  /// Fetch all children for the given user as a list of ChildModel.
  Future<List<ChildModel>> getChildrenData(String userId);

  /// Fetch a therapist’s data as a TherapistModel (or null if not found).
  Future<TherapistModel?> getTherapistData(String therapistId);

  /// Fetch a user’s data as a UserModel (or null if not found).
  Future<UserModel?> getUserData(String userId);

  /// Fetch CARS forms for a child as a list of CarsFormModel.
  Future<List<CarsFormModel>> getCarsForms(String childId);

  /// Update a child's data.
  Future<void> updateChild(String childId, Map<String, dynamic> data);

  /// Upload a child's photo and return the download URL.
  Future<String> uploadChildPhoto(String childId, File photo);

  /// Delete all data related to a child.
  Future<void> deleteChildData(String childId);

  /// Delete a parent's account and all associated children data.
  Future<void> deleteParentAccount(String userId);
}

class ProfileRepository implements IProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<UserModel> getParentData(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      throw Exception('Parent not found');
    }
    return UserModel.fromFirestore(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  @override
  Future<List<ChildModel>> getChildrenData(String userId) async {
    final snapshot = await _firestore
        .collection('child')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map(
          (doc) => ChildModel.fromFirestore(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  @override
  Future<TherapistModel?> getTherapistData(String therapistId) async {
    final snapshot =
        await _firestore.collection('therapist').doc(therapistId).get();
    if (!snapshot.exists) return null;
    return TherapistModel.fromFirestore(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  @override
  Future<UserModel?> getUserData(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) return null;
    return UserModel.fromFirestore(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  @override
  Future<List<CarsFormModel>> getCarsForms(String childId) async {
    final snapshot = await _firestore
        .collection('Cars')
        .where('childId', isEqualTo: childId)
        .get();
    return snapshot.docs
        .map(
          (doc) => CarsFormModel.fromFirestore(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  @override
  Future<void> updateChild(String childId, Map<String, dynamic> data) async {
    await _firestore.collection('child').doc(childId).update(data);
  }

  @override
  Future<String> uploadChildPhoto(String childId, File photo) async {
    final ref = _storage.ref().child('child_images/$childId.jpg');
    await ref.putFile(photo);
    return await ref.getDownloadURL();
  }

  @override
  Future<void> deleteChildData(String childId) async {
    // Delete associated CARS forms first.
    final carsForms = await getCarsForms(childId);
    for (var form in carsForms) {
      await _firestore.collection('Cars').doc(form.formId).delete();
    }
    // Then delete the child document.
    await _firestore.collection('child').doc(childId).delete();
  }

  @override
  Future<void> deleteParentAccount(String userId) async {
    try {
      // Step 1: Delete all children data associated with the parent
      final children = await getChildrenData(userId);
      for (var child in children) {
        // Delete child photo from storage if it exists
        if (child.childPhoto.isNotEmpty) {
          try {
            await _storage
                .ref()
                .child('child_images/${child.childId}.jpg')
                .delete();
          } catch (e) {
            // Ignore if file doesn't exist
            print('No photo found to delete for child: ${child.childId}');
          }
        }
        // Delete child document and associated data
        await deleteChildData(child.childId);
      }

      // Step 2: Delete the parent document from users collection
      await _firestore.collection('users').doc(userId).delete();

      // Step 3: Delete the Firebase Auth user
      try {
        final user = _auth.currentUser;
        if (user != null && user.uid == userId) {
          // Re-authenticate if needed (might be required for sensitive operations)
          // This would require getting the password from the user
          await user.delete();
        } else {
          // If we're deleting a different user (admin operation)
          // This would require admin SDK in backend
          print(
              'Warning: Attempted to delete a user that is not currently logged in');
        }
      } catch (e) {
        print('Error deleting auth user: $e');
        // Consider whether to rethrow based on your error handling strategy
        throw Exception('Failed to delete authentication account: $e');
      }

      // Step 4: Clear local session
      // This should be handled in the UI after this method completes
    } catch (e) {
      print('Error in deleteParentAccount: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<void> reauthenticateAndDeleteUser(
      String email, String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Create credential
        AuthCredential credential =
            EmailAuthProvider.credential(email: email, password: password);

        // Reauthenticate
        await user.reauthenticateWithCredential(credential);

        // Delete user
        await user.delete();
      }
    } catch (e) {
      throw Exception('Failed to reauthenticate: $e');
    }
  }
}
