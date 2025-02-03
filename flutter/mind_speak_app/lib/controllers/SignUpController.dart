import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mind_speak_app/components/navigationpage.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../service/local_auth_service.dart';

class SignUpController {
  final BuildContext context;
  final GlobalKey<FormState> formKey;

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

  
  Future<String> uploadImageToStorage(File image, String folderName) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef =
          FirebaseStorage.instance.ref().child('$folderName/$fileName');
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

 
  Future<bool> isValueTaken(
      String collection, String field, String value) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  
  Future<void> registration() async {
    if (!formKey.currentState!.validate()) return;

    try {
      
      if (!_validateImageUploads()) return;

      
      if (!await _checkDuplicateEntries()) return;

      
      UserCredential userCredential = await _createFirebaseUser();
      String userId = userCredential.user!.uid;

      
      await _saveUserDetails(userId);

      
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
      QuerySnapshot parentQuery = await FirebaseFirestore.instance
          .collection('child')
          .where('parentnumber', isEqualTo: parentPhoneNumber)
          .get();

      if (parentQuery.docs.isNotEmpty) {
        _showErrorSnackBar("Phone number is already in use by another parent.");
        return false;
      }
    }

    if (role == 'therapist') {
      int therapistPhoneNumber =
          int.parse(therapistPhoneNumberController.text.trim());
      QuerySnapshot therapistQuery = await FirebaseFirestore.instance
          .collection('therapist')
          .where('therapistnumber', isEqualTo: therapistPhoneNumber)
          .get();

      if (therapistQuery.docs.isNotEmpty) {
        _showErrorSnackBar(
            "Phone number is already in use by another therapist.");
        return false;
      }

      String nationalId = nationalIdController.text.trim();
      QuerySnapshot nationalIdQuery = await FirebaseFirestore.instance
          .collection('therapist')
          .where('nationalid', isEqualTo: nationalId)
          .get();

      if (nationalIdQuery.docs.isNotEmpty) {
        _showErrorSnackBar("National ID is already in use.");
        return false;
      }
    }

    return true;
  }

  Future<UserCredential> _createFirebaseUser() async {
    String email = emailController.text.trim();
    String password = hashPassword(passwordController.text.trim());
    return await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> _saveUserDetails(String userId) async {
    final Uuid uuid = const Uuid();

    if (role == 'parent') {
      String childImageUrl = childImage != null
          ? await uploadImageToStorage(childImage!, 'child_images')
          : '';
      String childId = uuid.v4();

      await FirebaseFirestore.instance.collection('child').doc(childId).set({
        'childId': childId,
        'name': childNameController.text.trim(),
        'age': int.parse(childAgeController.text.trim()),
        'childInterest': childInterestController.text.trim(),
        'childPhoto': childImageUrl,
        'userId': userId,
        'parentnumber': int.parse(parentPhoneNumberController.text.trim()),
        'therapistId': '',
        'assigned': false,
      });
    } else if (role == 'therapist') {
      String nationalProofUrl = nationalProofImage != null
          ? await uploadImageToStorage(nationalProofImage!, 'national_proofs')
          : '';
      String therapistImageUrl = therapistImage != null
          ? await uploadImageToStorage(therapistImage!, 'Therapists_images')
          : '';

      await FirebaseFirestore.instance.collection('therapist').doc(userId).set({
        'bio': bioController.text.trim(),
        'nationalid': nationalIdController.text.trim(),
        'nationalproof': nationalProofUrl,
        'therapistimage': therapistImageUrl,
        'status': false,
        'therapistnumber':
            int.parse(therapistPhoneNumberController.text.trim()),
        'therapistid': userId,
        'userid': userId
      });
    }

    
    await FirebaseFirestore.instance.collection('user').doc(userId).set({
      'email': emailController.text.trim(),
      'password': hashPassword(passwordController.text.trim()),
      'role': role,
      'userid': userId,
      'username': usernameController.text.trim(),
      'biometricEnabled': false,
    });
  }

  Future<void> _handleBiometricAuth(String userId) async {
    bool enableBiometric = await LocalAuth.hasBiometrics();
    if (enableBiometric) {
      bool biometricEnabled = await LocalAuth.authenticate();
      if (biometricEnabled) {
        await FirebaseFirestore.instance
            .collection('user')
            .doc(userId)
            .update({'biometricEnabled': true});
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
