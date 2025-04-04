import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/LoginRepository.dart';
import 'package:mind_speak_app/models/CarsFrom.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/pages/adminDashboard.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
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
      print("🔐 Starting login...");
      String email = mailController.text.trim();
      String password = passwordController.text.trim();

      print("Email: $email");
      print("Password: $password");

      print("📨 Authenticating...");
      UserModel user = await _loginRepository.authenticateUser(email, password);
      print("✅ Auth success for: ${user.username}");

      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.saveSession(user.userId, user.role);

      await _navigateBasedOnRole(user.role, user.userId);

      _showSuccessSnackBar("Logged in Successfully");
    } catch (e) {
      print("❌ Error during login: $e");
      _showErrorSnackBar(e.toString());
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
        await _handleTherapistNavigation(userId, therapist);
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
      String userId, TherapistModel therapist) async {
    if (!therapist.status) {
      throw Exception("Your account is not yet approved by the admin.");
    }

    try {
      print("🧠 Therapist approved, navigating to dashboard...");
      print("👤 Fetching user info for: $userId");

      Map<String, dynamic> userInfo = await _doctorServices.getUserInfo(userId);

      print("✅ User info fetched: $userInfo");

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
      print("🔥 Error in _handleTherapistNavigation: $e");
      _showErrorSnackBar(e.toString());
    }
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
