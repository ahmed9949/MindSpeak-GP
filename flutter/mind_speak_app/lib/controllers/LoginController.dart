import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/LoginRepository.dart';
import 'package:provider/provider.dart';

import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/local_auth_service.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';

class LoginController {
  final BuildContext context;
  final TextEditingController mailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final LoginRepository _loginRepository = LoginRepository();
  final DoctorDashboardService _doctorServices = DoctorDashboardService();

  LoginController({
    required this.context,
    required this.mailController,
    required this.passwordController,
    required this.formKey,
  });

  Future<void> signInWithGoogle() async {
    try {
      await _loginRepository.signInWithGoogle();
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const HomePage()));
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> userLogin() async {
    if (!formKey.currentState!.validate()) return;

    try {
      String email = mailController.text.trim();
      String password = passwordController.text.trim();

      // Authenticate user
      var authResult = await _loginRepository.authenticateUser(email, password);
      String userId = authResult['userId'];
      var userData = authResult['userData'];

      String role = userData['role'];
      bool isApproved = userData['status'] ?? false;
      bool biometricEnabled = userData['biometricEnabled'] ?? false;

      // Save session data
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.saveSession(userId, role);

      // Handle biometric authentication
      await _handleBiometricAuth(userId, biometricEnabled);

      // Navigate based on user role
      await _navigateBasedOnRole(role, userId, isApproved);

      _showSuccessSnackBar("Logged in Successfully");
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _handleBiometricAuth(
      String userId, bool biometricEnabled) async {
    if (biometricEnabled) {
      bool authenticated = await LocalAuth.authenticate();
      if (!authenticated) {
        throw Exception("Biometric authentication failed.");
      }
    } else {
      // Prompt to enable biometrics
      bool enableBiometric = await LocalAuth.linkBiometrics();
      if (enableBiometric) {
        await _loginRepository.updateBiometricStatus(userId, true);
      }
    }
  }

  Future<void> _navigateBasedOnRole(
      String role, String userId, bool isApproved) async {
    switch (role) {
      case 'parent':
        await _handleParentNavigation(userId);
        break;
      case 'therapist':
        await _handleTherapistNavigation(userId, isApproved);
        break;
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashBoard()),
        );
        break;
      default:
        throw Exception("Unknown role detected.");
    }
  }

  Future<void> _handleParentNavigation(String userId) async {
    try {
      // Fetch child data
      var childData = await _loginRepository.fetchChildData(userId);
      String childId = childData['childId'];

      // Check Cars form status
      var carsFormStatus = await _loginRepository.fetchCarsFormStatus(childId);

      if (carsFormStatus['exists'] && carsFormStatus['status']) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const carsform()),
        );
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _handleTherapistNavigation(
      String userId, bool isApproved) async {
    if (!isApproved) {
      throw Exception("Your account is not yet approved by the admin.");
    }

    try {
      Map<String, dynamic> therapistInfo =
          await _loginRepository.fetchTherapistInfo(userId);
      Map<String, dynamic> userInfo = await _doctorServices.getUserInfo(userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorDashboard(
            sessionId: userId,
            therapistInfo: therapistInfo,
            userInfo: userInfo,
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    return await LocalAuth.authenticate();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.redAccent,
      content: Text(
        message,
        style: const TextStyle(fontSize: 18.0),
      ),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text(
        message,
        style: const TextStyle(fontSize: 18.0),
      ),
    ));
  }
}
