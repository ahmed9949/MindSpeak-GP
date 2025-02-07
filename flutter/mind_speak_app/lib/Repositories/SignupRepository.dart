import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

abstract class ISignUpRepository {
  // Image handling
  Future<String> uploadImage(File image, String folderName);

  // Password handling
  String hashPassword(String password);

  // Duplicate checks
  Future<bool> isValueTaken(String collection, String field, String value);
  Future<bool> isParentPhoneNumberTaken(int phoneNumber);
  Future<bool> isTherapistPhoneNumberTaken(int phoneNumber);
  Future<bool> isNationalIdTaken(String nationalId);

  // User creation and management
  Future<UserCredential> createFirebaseUser(UserModel user);
  Future<void> saveParentAndChildDetails(ChildModel child);
  Future<void> saveTherapistDetails(TherapistModel therapist);
  Future<void> saveUserDetails(UserModel user);
  Future<void> updateBiometricStatus(String userId, bool enabled);

  // Utility
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

  // Upload image to Firebase Storage
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

  // Hash password
  @override
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  // Check if value exists in collection
  @override
  Future<bool> isValueTaken(
      String collection, String field, String value) async {
    final querySnapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  // Check for duplicate parent phone number
  @override
  Future<bool> isParentPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot parentQuery = await _firestore
        .collection('child')
        .where('parentnumber', isEqualTo: phoneNumber)
        .get();
    return parentQuery.docs.isNotEmpty;
  }

  // Check for duplicate therapist phone number
  @override
  Future<bool> isTherapistPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot therapistQuery = await _firestore
        .collection('therapist')
        .where('therapistnumber', isEqualTo: phoneNumber)
        .get();
    return therapistQuery.docs.isNotEmpty;
  }

  // Check for duplicate national ID
  @override
  Future<bool> isNationalIdTaken(String nationalId) async {
    QuerySnapshot nationalIdQuery = await _firestore
        .collection('therapist')
        .where('nationalid', isEqualTo: nationalId)
        .get();
    return nationalIdQuery.docs.isNotEmpty;
  }

  // Create Firebase user
  @override
  Future<UserCredential> createFirebaseUser(UserModel user) async {
    return await _auth.createUserWithEmailAndPassword(
      email: user.email,
      password: hashPassword(user.password), // Hash the password
    );
  }

  // Save parent and child details
  @override
  Future<void> saveParentAndChildDetails(ChildModel child) async {
    await _firestore.collection('child').doc(child.childId).set({
      'childId': child.childId,
      'name': child.name,
      'age': child.age,
      'childInterest': child.childInterest,
      'childPhoto': child.childPhoto,
      'userId': child.userId,
      'parentnumber': child.parentNumber,
      'therapistId': child.therapistId,
      'assigned': child.assigned,
    });
  }

  // Save therapist details
  @override
  Future<void> saveTherapistDetails(TherapistModel therapist) async {
    await _firestore.collection('therapist').doc(therapist.therapistId).set({
      'bio': therapist.bio,
      'nationalid': therapist.nationalId,
      'nationalproof': therapist.nationalProof,
      'therapistimage': therapist.therapistImage,
      'status': therapist.status,
      'therapistnumber': therapist.therapistPhoneNumber,
      'therapistid': therapist.therapistId,
      'userid': therapist.userId,
    });
  }

  // Save user details
  @override
  Future<void> saveUserDetails(UserModel user) async {
    await _firestore.collection('user').doc(user.userId).set({
      'email': user.email,
      'password':
          hashPassword(user.password), // Use the password from UserModel
      'role': user.role,
      'userid': user.userId,
      'username': user.username,
      'biometricEnabled': user.biometricEnabled,
    });
  }

  // Update biometric status
  @override
  Future<void> updateBiometricStatus(String userId, bool enabled) async {
    await _firestore
        .collection('user')
        .doc(userId)
        .update({'biometricEnabled': enabled});
  }
}
