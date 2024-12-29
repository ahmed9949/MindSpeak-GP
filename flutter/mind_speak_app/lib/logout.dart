import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/login.dart';
 
Future<void> logout(BuildContext context) async {
  try {
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Navigate to Login Page and clear the navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LogIn()),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  } catch (e) {
    // Handle any errors during sign-out
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
