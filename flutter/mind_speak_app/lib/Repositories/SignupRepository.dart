import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/ParentModel.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

abstract class ISignUpRepository {
  Future<String> uploadImage(File image, String folderName);
  String hashPassword(String password);
  Future<bool> isValueTaken(String collection, String field, String value);
  Future<bool> isParentPhoneNumberTaken(int phoneNumber);
  Future<bool> isTherapistPhoneNumberTaken(int phoneNumber);
  Future<bool> isNationalIdTaken(String nationalId);
  Future<UserCredential> createFirebaseUser(UserModel user);
  Future<void> saveUserDetails(UserModel user);
  Future<void> saveSpecificDetails(
      String collection, Map<String, dynamic> data, String id);
  Future<void> saveParentAndChildDetails(ChildModel child);
  Future<void> saveTherapistDetails(TherapistModel therapist);
  Future<void> saveParentDetails(ParentModel parent);
  Future<void> updateBiometricStatus(String userId, bool enabled);
  String generateChildId();
}

class SignupRepository implements ISignUpRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  @override
  String generateChildId() {
    return _uuid.v4();
  }

  @override
  Future<String> uploadImage(File image, String folderName) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child('$folderName/$fileName');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  @override
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  @override
  Future<bool> isValueTaken(
      String collection, String field, String value) async {
    final querySnapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  @override
  Future<bool> isParentPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot parentQuery = await _firestore
        .collection('parent')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .get();
    return parentQuery.docs.isNotEmpty;
  }

  @override
  Future<bool> isTherapistPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot therapistQuery = await _firestore
        .collection('therapist')
        .where('therapistNumber', isEqualTo: phoneNumber)
        .get();
    return therapistQuery.docs.isNotEmpty;
  }

  @override
  Future<bool> isNationalIdTaken(String nationalId) async {
    QuerySnapshot nationalIdQuery = await _firestore
        .collection('therapist')
        .where('nationalid', isEqualTo: nationalId)
        .get();
    return nationalIdQuery.docs.isNotEmpty;
  }

  @override
  Future<UserCredential> createFirebaseUser(UserModel user) async {
    print(
        "Creating Firebase user with: ${user.email}, ${user.password}"); // 👈 Debug print
    return await _auth.createUserWithEmailAndPassword(
      email: user.email,
      password: user.password, // Use plain password for Firebase Auth
    );
  }

  @override
  Future<void> saveUserDetails(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.userId)
        .set(user.toFirestore());
  }

  @override
  Future<void> saveSpecificDetails(
      String collection, Map<String, dynamic> data, String id) async {
    await _firestore.collection(collection).doc(id).set(data);
  }

  @override
  Future<void> saveParentAndChildDetails(ChildModel child) async {
    await _firestore
        .collection('child')
        .doc(child.childId)
        .set(child.toFirestore());
  }

  @override
  Future<void> saveTherapistDetails(TherapistModel therapist) async {
    await _firestore
        .collection('therapist')
        .doc(therapist.therapistId)
        .set(therapist.toFirestore());
  }

  @override
  Future<void> saveParentDetails(ParentModel parent) async {
    await _firestore
        .collection('parent')
        .doc(parent.parentId)
        .set(parent.toFirestore());
  }

  @override
  Future<void> updateBiometricStatus(String userId, bool enabled) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'biometricEnabled': enabled});
  }
}
