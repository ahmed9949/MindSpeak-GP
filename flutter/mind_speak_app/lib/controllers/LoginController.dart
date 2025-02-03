import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';
import 'package:mind_speak_app/service/local_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class LoginController {
  final BuildContext context;
  final TextEditingController mailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final DoctorDashboardService _doctorServices = DoctorDashboardService();

  LoginController({
    required this.context,
    required this.mailController,
    required this.passwordController,
    required this.formKey,
  });

  // *Hashing Function*
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  Future<void> signInWithGoogle() async {
    GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken, idToken: googleAuth?.idToken);
    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    if (userCredential.user != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const HomePage()));
    }
  }

  Future<void> userLogin() async {
    if (!formKey.currentState!.validate()) return;

    try {
      String email = mailController.text.trim();
      String enteredPassword = passwordController.text.trim();
      String hashedEnteredPassword = hashPassword(enteredPassword);

      // Fetch user from Firestore by email
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception("No user found with this email.");
      }

      var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
      String storedPassword = userData['password'];
      String role = userData['role'];
      bool isApproved = userData['status'] ?? false;
      bool biometricEnabled = userData['biometricEnabled'] ?? false;
      String userId = userSnapshot.docs.first.id;

      if (hashedEnteredPassword == storedPassword) {
        // Save session data using SessionProvider
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);
        await sessionProvider.saveSession(userSnapshot.docs.first.id, role);

        if (biometricEnabled) {
          // Authenticate using biometrics
          bool authenticated = await LocalAuth.authenticate();

          if (!authenticated) {
            throw Exception("Biometric authentication failed.");
          }
        } else {
          // Prompt to enable biometrics if not already enabled
          bool enableBiometric = await LocalAuth.linkBiometrics();
          if (enableBiometric) {
            await FirebaseFirestore.instance
                .collection('user')
                .doc(userId)
                .update({'biometricEnabled': true});
          }
        }

        await _navigateBasedOnRole(userSnapshot, role, userId, isApproved);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Logged in Successfully",
            style: TextStyle(fontSize: 18.0),
          ),
        ));
      } else {
        throw Exception("Incorrect password.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          e.toString(),
          style: const TextStyle(fontSize: 18.0),
        ),
      ));
    }
  }

  Future<void> _navigateBasedOnRole(QuerySnapshot userSnapshot, String role,
      String userId, bool isApproved) async {
    if (role == 'parent') {
      await _handleParentNavigation(userSnapshot);
    } else if (role == 'therapist') {
      await _handleTherapistNavigation(userSnapshot, isApproved);
    } else if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashBoard()),
      );
    } else {
      throw Exception("Unknown role detected.");
    }
  }

  Future<void> _handleParentNavigation(QuerySnapshot userSnapshot) async {
    // Fetch child data for the current user
    QuerySnapshot childSnapshot = await FirebaseFirestore.instance
        .collection('child')
        .where('userId', isEqualTo: userSnapshot.docs.first.id)
        .get();

    if (childSnapshot.docs.isNotEmpty) {
      final childId = childSnapshot.docs.first['childId'];

      // Check if the Cars form is completed
      QuerySnapshot carsSnapshot = await FirebaseFirestore.instance
          .collection('Cars')
          .where('childId', isEqualTo: childId)
          .get();

      if (carsSnapshot.docs.isNotEmpty) {
        final carsData = carsSnapshot.docs.first.data() as Map<String, dynamic>;
        bool formStatus = carsData['status'] ?? false;

        if (formStatus) {
          // Navigate to HomePage if Cars form is completed
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          // Navigate to carsform if Cars form is not completed
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const carsform()),
          );
        }
      } else {
        // Navigate to carsform if no Cars form exists
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const carsform()),
        );
      }
    } else {
      throw Exception("No child associated with this parent.");
    }
  }

  Future<void> _handleTherapistNavigation(
      QuerySnapshot userSnapshot, bool isApproved) async {
    if (isApproved) {
      try {
        Map<String, dynamic> therapistInfo =
            await _doctorServices.getTherapistInfo(userSnapshot.docs.first.id);
        Map<String, dynamic> userInfo =
            await _doctorServices.getUserInfo(userSnapshot.docs.first.id);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorDashboard(
              sessionId: userSnapshot.docs.first.id,
              therapistInfo: therapistInfo,
              userInfo: userInfo,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            e.toString(),
            style: const TextStyle(fontSize: 18.0),
          ),
        ));
      }
    } else {
      throw Exception("Your account is not yet approved by the admin.");
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    return await LocalAuth.authenticate();
  }
}
