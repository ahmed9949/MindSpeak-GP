import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mind_speak_app/components/navigationpage.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/service/SignupRepository.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import '../service/local_auth_service.dart';

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

      // Create Firebase user
      UserCredential userCredential = await _repository.createFirebaseUser(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      String userId = userCredential.user!.uid;

      // Upload images and save details based on role
      if (role == 'parent') {
        String childImageUrl = childImage != null
            ? await _repository.uploadImage(childImage!, 'child_images')
            : '';

        await _repository.saveParentAndChildDetails(
          userId: userId,
          childName: childNameController.text.trim(),
          childAge: int.parse(childAgeController.text.trim()),
          childInterest: childInterestController.text.trim(),
          childImageUrl: childImageUrl,
          parentPhoneNumber: int.parse(parentPhoneNumberController.text.trim()),
        );
      } else if (role == 'therapist') {
        String nationalProofUrl = nationalProofImage != null
            ? await _repository.uploadImage(
                nationalProofImage!, 'national_proofs')
            : '';
        String therapistImageUrl = therapistImage != null
            ? await _repository.uploadImage(
                therapistImage!, 'Therapists_images')
            : '';

        await _repository.saveTherapistDetails(
          userId: userId,
          bio: bioController.text.trim(),
          nationalId: nationalIdController.text.trim(),
          nationalProofUrl: nationalProofUrl,
          therapistImageUrl: therapistImageUrl,
          therapistPhoneNumber:
              int.parse(therapistPhoneNumberController.text.trim()),
        );
      }

      // Save user details
      await _repository.saveUserDetails(
        userId: userId,
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        role: role,
        username: usernameController.text.trim(),
      );

      await _handleBiometricAuth(userId);
      _navigateBasedOnRole();
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

  Future<void> _handleBiometricAuth(String userId) async {
    bool enableBiometric = await LocalAuth.hasBiometrics();
    if (enableBiometric) {
      bool biometricEnabled = await LocalAuth.authenticate();
      if (biometricEnabled) {
        await _repository.updateBiometricStatus(userId, true);
        _showSuccessSnackBar("Biometric authentication enabled successfully.");
      }
    }

    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    await sessionProvider.saveSession(userId, role);
  }

  void _navigateBasedOnRole() {
    _showSuccessSnackBar("Registered Successfully");

    switch (role) {
      case 'parent':
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const Navigationpage()));
        break;
      case 'therapist':
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const LogIn()));
        _showInfoSnackBar(
            "Your account is pending approval. Please wait until the admin approves your request.");
        break;
      case 'admin':
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const DashBoard()));
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
