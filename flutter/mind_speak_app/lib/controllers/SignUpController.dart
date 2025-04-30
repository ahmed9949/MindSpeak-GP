import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mind_speak_app/Repositories/SignupRepository.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/ParentModel.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/pages/adminDashboard.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/service/notification_service.dart'; // <-- Import NotificationService

class SignUpController {
  final BuildContext context;
  final GlobalKey<FormState> formKey;
  final SignupRepository _repository = SignupRepository();

  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController childNameController;
  final TextEditingController childAgeController;
  final TextEditingController childInterestController;
  final TextEditingController nationalIdController;
  final TextEditingController bioController;
  final TextEditingController parentPhoneNumberController;
  final TextEditingController therapistPhoneNumberController;

  String role;
  File? childImage;
  File? nationalProofImage;
  File? therapistImage;
  bool isLoading = false;

  SignUpController({
    required this.context,
    required this.formKey,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.childNameController,
    required this.childAgeController,
    required this.childInterestController,
    required this.nationalIdController,
    required this.bioController,
    required this.parentPhoneNumberController,
    required this.therapistPhoneNumberController,
    this.role = 'parent',
    this.childImage,
    this.nationalProofImage,
    this.therapistImage,
  });

  Future<File?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  Future<void> registration() async {
    if (!formKey.currentState!.validate()) return;

    try {
      if (!_validateImageUploads()) return;
      if (!await _checkDuplicateEntries()) return;

      int phoneNumber;
      if (role == 'parent') {
        phoneNumber = int.parse(parentPhoneNumberController.text.trim());
      } else if (role == 'therapist') {
        phoneNumber = int.parse(therapistPhoneNumberController.text.trim());
      } else {
        phoneNumber = 0;
      }

      String plainPassword = passwordController.text.trim();

      final user = UserModel(
        userId: '',
        email: emailController.text.trim(),
        username: usernameController.text.trim(),
        role: role,
        password: plainPassword,
        phoneNumber: phoneNumber,
      );

      UserCredential userCredential =
          await _repository.createFirebaseUser(user);

      await userCredential.user!.sendEmailVerification();

      _showInfoSnackBar(
          "Verification email sent. Please check your Gmail and verify before logging in.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LogIn()),
      );

      String userId = userCredential.user!.uid;

      final updatedUser = UserModel(
        userId: userId,
        email: user.email,
        username: user.username,
        role: user.role,
        password: _repository.hashPassword(plainPassword),
        phoneNumber: user.phoneNumber,
      );

      await _repository.saveUserDetails(updatedUser);

      if (role == 'parent') {
        final parent = ParentModel(
          parentId: userId,
          phoneNumber: int.parse(parentPhoneNumberController.text.trim()),
        );
        await _repository.saveParentDetails(parent);

        String childImageUrl = childImage != null
            ? await _repository.uploadImage(childImage!, 'child_images')
            : '';

        final child = ChildModel(
          childId: _repository.generateChildId(),
          name: childNameController.text.trim(),
          age: int.parse(childAgeController.text.trim()),
          childInterest: childInterestController.text.trim(),
          childPhoto: childImageUrl,
          therapistId: '',
          assigned: false,
          userId: userId,
        );
        await _repository.saveParentAndChildDetails(child);
      } else if (role == 'therapist') {
        String nationalProofUrl = nationalProofImage != null
            ? await _repository.uploadImage(
                nationalProofImage!, 'national_proofs')
            : '';
        String therapistImageUrl = therapistImage != null
            ? await _repository.uploadImage(therapistImage!, 'therapist_images')
            : '';

        final therapist = TherapistModel(
          therapistId: userId,
          bio: bioController.text.trim(),
          nationalId: nationalIdController.text.trim(),
          nationalProof: nationalProofUrl,
          therapistImage: therapistImageUrl,
          status: false,
          userId: userId,
        );
        await _repository.saveTherapistDetails(therapist);

        // 🔔 Send Local Notification to Admin
        await NotificationService.showNotification(
          title: "New Therapist Registration",
          body:
              "${usernameController.text.trim()} has registered and awaits approval.",
        );
      }

      _navigateBasedOnRole(userId);
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _showErrorSnackBar("Registration failed: ${e.toString()}");
    }
  }

  bool _validateImageUploads() {
    if (role == 'parent' && childImage == null) {
      _showErrorSnackBar("Please upload your child's image.");
      return false;
    }
    if (role == 'therapist' &&
        (nationalProofImage == null || therapistImage == null)) {
      _showErrorSnackBar("Please upload national proof and therapist image.");
      return false;
    }
    return true;
  }

  Future<bool> _checkDuplicateEntries() async {
    if (role == 'parent') {
      int parentPhoneNumber =
          int.parse(parentPhoneNumberController.text.trim());
      if (await _repository.isParentPhoneNumberTaken(parentPhoneNumber)) {
        _showErrorSnackBar("Phone number is already in use by another parent.");
        return false;
      }
    }
    if (role == 'therapist') {
      int therapistPhoneNumber =
          int.parse(therapistPhoneNumberController.text.trim());
      if (await _repository.isTherapistPhoneNumberTaken(therapistPhoneNumber)) {
        _showErrorSnackBar(
            "Phone number is already in use by another therapist.");
        return false;
      }
      String nationalId = nationalIdController.text.trim();
      if (await _repository.isNationalIdTaken(nationalId)) {
        _showErrorSnackBar("National ID is already in use.");
        return false;
      }
    }
    return true;
  }

  void _navigateBasedOnRole(String userId) {
    _showSuccessSnackBar("Registered Successfully");

    switch (role) {
      case 'parent':
        Provider.of<SessionProvider>(context, listen: false)
            .saveSession(userId, role);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CarsForm()),
        );
        break;
      case 'therapist':
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const LogIn()));
        break;
      case 'admin':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AdminDashboardView()));
        break;
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        _showErrorSnackBar("Password Provided is too Weak");
        break;
      case 'email-already-in-use':
        _showErrorSnackBar("Account Already exists");
        break;
      default:
        print("Error: ${e.toString()}");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 20.0)),
      backgroundColor: Colors.green,
    ));
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orangeAccent,
    ));
  }
}
