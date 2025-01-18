import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';

Future<void> logout(BuildContext context) async {
  try {
    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    await sessionProvider.clearSession();
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
