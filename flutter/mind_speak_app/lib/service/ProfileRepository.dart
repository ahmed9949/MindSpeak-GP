import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileRepository {
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

  // Fetch parent data
  Future<Map<String, dynamic>> getParentData(String userId) async {
    final snapshot = await _firestore.collection('user').doc(userId).get();
    if (!snapshot.exists) {
      throw Exception('Parent not found');
    }
    return snapshot.data() as Map<String, dynamic>;
  }

  // Fetch children data
  Future<List<QueryDocumentSnapshot>> getChildrenData(String userId) async {
    final snapshot = await _firestore
        .collection('child')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs;
  }

  // Fetch therapist data
  Future<Map<String, dynamic>?> getTherapistData(String therapistId) async {
    final snapshot =
        await _firestore.collection('therapist').doc(therapistId).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  // Fetch user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final snapshot = await _firestore.collection('user').doc(userId).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  // Fetch CARS forms for a child
  Future<List<QueryDocumentSnapshot>> getCarsForms(String childId) async {
    final snapshot = await _firestore
        .collection('Cars')
        .where('childId', isEqualTo: childId)
        .get();
    return snapshot.docs;
  }

  // Update child data
  Future<void> updateChild(String childId, Map<String, dynamic> data) async {
    await _firestore.collection('child').doc(childId).update(data);
  }

  // Upload child photo
  Future<String> uploadChildPhoto(String childId, File photo) async {
    final ref = _storage.ref().child('child_images/$childId.jpg');
    await ref.putFile(photo);
    return await ref.getDownloadURL();
  }

  // Delete all child data
  Future<void> deleteChildData(String childId) async {
    // Delete CARS forms
    final carsForms = await getCarsForms(childId);
    for (var form in carsForms) {
      await _firestore.collection('Cars').doc(form.id).delete();
    }

    // Delete child document
    await _firestore.collection('child').doc(childId).delete();
  }

  // Delete parent account
  Future<void> deleteParentAccount(String userId) async {
    // Get all children
    final children = await getChildrenData(userId);

    // Delete each child's data
    for (var child in children) {
      await deleteChildData(child.id);
    }

    // Delete parent document
    await _firestore.collection('user').doc(userId).delete();

    // Delete auth user
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
