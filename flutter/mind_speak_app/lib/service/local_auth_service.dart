import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalAuth {
  static final _auth = LocalAuthentication();
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print("Error checking biometrics: $e");
      return false;
    }
  }

  static Future<bool> authenticate() async {
    final isAvailable = await hasBiometrics();
    if (!isAvailable) return false;

    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to authenticate',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }

  static Future<bool> linkBiometrics() async {
    final isAvailable = await hasBiometrics();
    if (!isAvailable) return false;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Enable biometric login for your account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        final User? user = _firebaseAuth.currentUser;

        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'biometricEnabled': true,
          });
          print(
              "Biometric authentication enabled for user: ${user.displayName}");
          return true;
        }
      }

      return false;
    } catch (e) {
      print("Error enabling biometrics: $e");
      return false;
    }
  }



   static Future<Map<String, dynamic>?> authenticateWithBiometrics() async {
    final isAvailable = await hasBiometrics();
    if (!isAvailable) return null;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate with biometrics',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        final User? user = _firebaseAuth.currentUser;

        if (user != null) {
          final DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(user.uid).get();

          if (userDoc.exists) {
            print("User data: ${userDoc.data()}");
            return userDoc.data() as Map<String, dynamic>;
          } else {
            print("No user data found for UID: ${user.uid}");
          }
        }
      }

      return null;
    } catch (e) {
      print("Authentication error: $e");
      return null;
    }
  }
}
