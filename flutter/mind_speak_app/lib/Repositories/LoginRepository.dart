import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind_speak_app/models/CarsFrom.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';

abstract class ILoginRepository {
  Future<UserModel> authenticateUser(String email, String password);
  Future<UserModel> signInWithGoogle();
  Future<ChildModel> fetchChildData(String userId);
  Future<CarsFormModel?> fetchCarsFormStatus(String childId);
  Future<TherapistModel> fetchTherapistInfo(String userId);
  Future<void> updateBiometricStatus(String userId, bool status);
}

class LoginRepository implements ILoginRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  @override
  Future<UserModel> authenticateUser(String email, String password) async {
    try {
      // Use Firebase Auth for authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String userId = userCredential.user!.uid;

      // After successful authentication, fetch the user details
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception("User details not found in database.");
      }

      return UserModel.fromFirestore(
          userDoc.data() as Map<String, dynamic>, userDoc.id);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception("No user found with this email.");
        case 'wrong-password':
          throw Exception("Incorrect password.");
        default:
          throw Exception("Authentication failed: ${e.message}");
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      UserCredential credential = await _performGoogleSignIn();
      User? user = credential.user;

      if (user == null) throw Exception("Google sign in failed");

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _createNewUser(user);
        userDoc = await _firestore.collection('users').doc(user.uid).get();
      }

      return UserModel.fromFirestore(
          userDoc.data() as Map<String, dynamic>, userDoc.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> _performGoogleSignIn() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken, idToken: googleAuth?.idToken);

    return await _auth.signInWithCredential(credential);
  }

  Future<void> _createNewUser(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'username': user.displayName,
      'role': 'user',
      'biometricEnabled': false,
      'phoneNumber': 0,
      'password': '', // Empty since we're using Google Auth
    });
  }

  @override
  Future<ChildModel> fetchChildData(String userId) async {
    try {
      QuerySnapshot childSnapshot = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (childSnapshot.docs.isEmpty) {
        throw Exception("No child associated with this parent.");
      }

      return ChildModel.fromFirestore(
          childSnapshot.docs.first.data() as Map<String, dynamic>,
          childSnapshot.docs.first.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CarsFormModel?> fetchCarsFormStatus(String childId) async {
    try {
      QuerySnapshot carsSnapshot = await _firestore
          .collection('Cars')
          .where('childId', isEqualTo: childId)
          .get();

      if (carsSnapshot.docs.isEmpty) return null;

      return CarsFormModel.fromFirestore(
          carsSnapshot.docs.first.data() as Map<String, dynamic>,
          carsSnapshot.docs.first.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TherapistModel> fetchTherapistInfo(String userId) async {
    try {
      DocumentSnapshot therapistDoc =
          await _firestore.collection('therapist').doc(userId).get();

      if (!therapistDoc.exists) {
        throw Exception("Therapist information not found.");
      }

      return TherapistModel.fromFirestore(
          therapistDoc.data() as Map<String, dynamic>, therapistDoc.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateBiometricStatus(String userId, bool status) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'biometricEnabled': status});
    } catch (e) {
      rethrow;
    }
  }
}
