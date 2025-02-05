import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SignupRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Upload image to Firebase Storage
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
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  // Check if value exists in collection
  Future<bool> isValueTaken(
      String collection, String field, String value) async {
    final querySnapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  // Check for duplicate parent phone number
  Future<bool> isParentPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot parentQuery = await _firestore
        .collection('child')
        .where('parentnumber', isEqualTo: phoneNumber)
        .get();
    return parentQuery.docs.isNotEmpty;
  }

  // Check for duplicate therapist phone number
  Future<bool> isTherapistPhoneNumberTaken(int phoneNumber) async {
    QuerySnapshot therapistQuery = await _firestore
        .collection('therapist')
        .where('therapistnumber', isEqualTo: phoneNumber)
        .get();
    return therapistQuery.docs.isNotEmpty;
  }

  // Check for duplicate national ID
  Future<bool> isNationalIdTaken(String nationalId) async {
    QuerySnapshot nationalIdQuery = await _firestore
        .collection('therapist')
        .where('nationalid', isEqualTo: nationalId)
        .get();
    return nationalIdQuery.docs.isNotEmpty;
  }

  // Create Firebase user
  Future<UserCredential> createFirebaseUser(
      String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: hashPassword(password),
    );
  }

  // Save parent and child details
  Future<void> saveParentAndChildDetails({
    required String userId,
    required String childName,
    required int childAge,
    required String childInterest,
    required String childImageUrl,
    required int parentPhoneNumber,
  }) async {
    String childId = _uuid.v4();
    await _firestore.collection('child').doc(childId).set({
      'childId': childId,
      'name': childName,
      'age': childAge,
      'childInterest': childInterest,
      'childPhoto': childImageUrl,
      'userId': userId,
      'parentnumber': parentPhoneNumber,
      'therapistId': '',
      'assigned': false,
    });
  }

  // Save therapist details
  Future<void> saveTherapistDetails({
    required String userId,
    required String bio,
    required String nationalId,
    required String nationalProofUrl,
    required String therapistImageUrl,
    required int therapistPhoneNumber,
  }) async {
    await _firestore.collection('therapist').doc(userId).set({
      'bio': bio,
      'nationalid': nationalId,
      'nationalproof': nationalProofUrl,
      'therapistimage': therapistImageUrl,
      'status': false,
      'therapistnumber': therapistPhoneNumber,
      'therapistid': userId,
      'userid': userId
    });
  }

  // Save user details
  Future<void> saveUserDetails({
    required String userId,
    required String email,
    required String password,
    required String role,
    required String username,
    bool biometricEnabled = false,
  }) async {
    await _firestore.collection('user').doc(userId).set({
      'email': email,
      'password': hashPassword(password),
      'role': role,
      'userid': userId,
      'username': username,
      'biometricEnabled': biometricEnabled,
    });
  }

  // Update biometric status
  Future<void> updateBiometricStatus(String userId, bool enabled) async {
    await _firestore
        .collection('user')
        .doc(userId)
        .update({'biometricEnabled': enabled});
  }
}
