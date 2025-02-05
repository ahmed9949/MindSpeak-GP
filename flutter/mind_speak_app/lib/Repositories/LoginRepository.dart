import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

 
  Future<Map<String, dynamic>> authenticateUser(
      String email, String password) async {
    try {
     
      QuerySnapshot userSnapshot = await _firestore
          .collection('user')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception("No user found with this email.");
      }

      var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
      String storedPassword = userData['password'];
      String hashedEnteredPassword = hashPassword(password);

      if (hashedEnteredPassword != storedPassword) {
        throw Exception("Incorrect password.");
      }

      return {
        'userData': userData,
        'userId': userSnapshot.docs.first.id,
      };
    } catch (e) {
      rethrow;
    }
  }

  
  Future<UserCredential> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken, idToken: googleAuth?.idToken);

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

 
  Future<Map<String, dynamic>> fetchChildData(String userId) async {
    try {
      QuerySnapshot childSnapshot = await _firestore
          .collection('child')
          .where('userId', isEqualTo: userId)
          .get();

      if (childSnapshot.docs.isEmpty) {
        throw Exception("No child associated with this parent.");
      }

      return {
        'childId': childSnapshot.docs.first['childId'],
        'childData': childSnapshot.docs.first.data() as Map<String, dynamic>
      };
    } catch (e) {
      rethrow;
    }
  }

  
  Future<Map<String, dynamic>> fetchCarsFormStatus(String childId) async {
    try {
      QuerySnapshot carsSnapshot = await _firestore
          .collection('Cars')
          .where('childId', isEqualTo: childId)
          .get();

      if (carsSnapshot.docs.isEmpty) {
        return {'exists': false, 'status': false};
      }

      var carsData = carsSnapshot.docs.first.data() as Map<String, dynamic>;
      return {'exists': true, 'status': carsData['status'] ?? false};
    } catch (e) {
      rethrow;
    }
  }

  
  Future<Map<String, dynamic>> fetchTherapistInfo(String userId) async {
    try {
      DocumentSnapshot therapistDoc =
          await _firestore.collection('therapist').doc(userId).get();

      if (!therapistDoc.exists) {
        throw Exception("Therapist information not found.");
      }

      return therapistDoc.data() as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Update Biometric Status
  Future<void> updateBiometricStatus(String userId, bool status) async {
    try {
      await _firestore
          .collection('user')
          .doc(userId)
          .update({'biometricEnabled': status});
    } catch (e) {
      rethrow;
    }
  }
}
