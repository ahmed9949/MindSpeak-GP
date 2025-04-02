import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/LoginRepository.dart';
import 'package:mind_speak_app/models/CarsFrom.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/pages/adminDashboard.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/local_auth_service.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
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
      UserModel user = await _loginRepository.signInWithGoogle();
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.saveSession(user.userId, user.role);

      _showSuccessSnackBar("Logged in Successfully with Google");
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()));
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> userLogin() async {
    if (!formKey.currentState!.validate()) return;

    try {
      String email = mailController.text.trim();
      String password = passwordController.text.trim();

      UserModel user = await _loginRepository.authenticateUser(email, password);

      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.saveSession(user.userId, user.role);

      await _handleBiometricAuth(user.userId, user.biometricEnabled);
      await _navigateBasedOnRole(user.role, user.userId);

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
      bool enableBiometric = await LocalAuth.linkBiometrics();
      if (enableBiometric) {
        await _loginRepository.updateBiometricStatus(userId, true);
      }
    }
  }

  Future<void> _navigateBasedOnRole(String role, String userId) async {
    switch (role) {
      case 'parent':
        await _handleParentNavigation(userId);
        break;
      case 'therapist':
        TherapistModel therapist =
            await _loginRepository.fetchTherapistInfo(userId);
        await _handleTherapistNavigation(userId, therapist.status);
        break;
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardView()),
        );
        break;
      default:
        throw Exception("Unknown role detected.");
    }
  }

  Future<void> _handleParentNavigation(String userId) async {
    try {
      ChildModel child = await _loginRepository.fetchChildData(userId);
      CarsFormModel? carsForm =
          await _loginRepository.fetchCarsFormStatus(child.childId);

      if (carsForm != null && carsForm.status) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CarsForm()),
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
      TherapistModel therapist =
          await _loginRepository.fetchTherapistInfo(userId);
      Map<String, dynamic> userInfo = await _doctorServices.getUserInfo(userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorDashboard(
            sessionId: userId,
            therapistInfo: therapist.toMap(),
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
      content: Text(message, style: const TextStyle(fontSize: 18.0)),
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text(message, style: const TextStyle(fontSize: 18.0)),
    ));
  }
}
