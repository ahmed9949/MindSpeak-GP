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
}

class LoginRepository implements ILoginRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  LoginRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  @override
  Future<UserModel> authenticateUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw Exception("Please verify your email before logging in.");
      }
      String userId = userCredential.user!.uid;

      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception("This account was rejected by the admin before.");
      }

      return UserModel.fromFirestore(userDoc.data()!, userDoc.id);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception("Incorrect email or password. Please try again.");
        default:
          throw Exception("Authentication failed. Please try again later.");
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

      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _createNewUser(user);
        userDoc = await _firestore.collection('users').doc(user.uid).get();
      }

      return UserModel.fromFirestore(userDoc.data()!, userDoc.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> _performGoogleSignIn() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> _createNewUser(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'therapistId': user.uid,
      'userId': user.uid,
      'email': user.email,
      'username': user.displayName,
      'role': 'user',
      'phoneNumber': 0,
      'password': '',
    });
  }

  @override
  Future<ChildModel> fetchChildData(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> childSnapshot = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (childSnapshot.docs.isEmpty) {
        throw Exception("No child associated with this parent.");
      }

      return ChildModel.fromFirestore(
          childSnapshot.docs.first.data(), childSnapshot.docs.first.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CarsFormModel?> fetchCarsFormStatus(String childId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> carsSnapshot = await _firestore
          .collection('Cars')
          .where('childId', isEqualTo: childId)
          .get();

      if (carsSnapshot.docs.isEmpty) return null;

      return CarsFormModel.fromFirestore(
          carsSnapshot.docs.first.data(), carsSnapshot.docs.first.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TherapistModel> fetchTherapistInfo(String userId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('therapist')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception("Therapist information not found.");
      }

      final doc = snapshot.docs.first;

      return TherapistModel.fromFirestore(doc.data(), doc.id);
    } catch (e) {
      rethrow;
    }
  }
}
