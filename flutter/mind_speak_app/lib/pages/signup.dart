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
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../service/local_auth_service.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = "", password = "", username = "", role = "parent";
  String childname = "", nationalid = "", childInterest = "";
  String bio = "";
  int childAge = 0;
  int parentPhonenumber = 0;
  int therapistPhonenumber = 0;
  bool status = false;
  File? _childImage;
  File? _nationalProofImage;
  File? _TherapistImage;
  bool isLoading = false;
  bool biometricEnabled = false;

  TextEditingController usernamecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController childNameController = TextEditingController();
  TextEditingController childAgeController = TextEditingController();
  TextEditingController childInterestController = TextEditingController();
  TextEditingController nationalIdController = TextEditingController();
  TextEditingController bioController = TextEditingController();
  TextEditingController parentPhoneNumberController = TextEditingController();
  TextEditingController therapistPhoneNumberController =
      TextEditingController();

  final _formkey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final Uuid uuid = const Uuid();

  Future<void> pickChildImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _childImage = File(pickedFile.path);
      });
    }
  }

  Future<void> pickNationalProofImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _nationalProofImage = File(pickedFile.path);
      });
    }
  }

  Future<void> pickTherapistImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _TherapistImage = File(pickedFile.path);
      });
    }
  }

  // Future<String> saveImageLocally(File image, String folderName) async {
  //   try {
  //     final directory = await getApplicationDocumentsDirectory();
  //     final folderPath = Directory('${directory.path}/$folderName');
  //     if (!folderPath.existsSync()) {
  //       folderPath.createSync(recursive: true);
  //     }
  //     final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  //     final localPath = '${folderPath.path}/$fileName';
  //     final savedImage = await image.copy(localPath);
  //     return savedImage.path;
  //   } catch (e) {
  //     throw Exception("Image save failed: $e");
  //   }
  // }

  Future<String> uploadImageToStorage(File image, String folderName) async {
    try {
      // Generate a unique file name
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Define the storage reference
      Reference storageRef =
          FirebaseStorage.instance.ref().child('$folderName/$fileName');

      // Upload the file to Firebase Storage
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  registration() async {
    setState(() {
      isLoading = true; // Show loading spinner immediately
    });
    if (_formkey.currentState!.validate()) {
      try {
        email = emailcontroller.text.trim();
        password = hashPassword(passwordcontroller.text.trim());
        username = usernamecontroller.text.trim();
        childname = childNameController.text.trim();
        bio = bioController.text.trim();
        nationalid = nationalIdController.text.trim();

        if (role == 'parent' && _childImage == null) {
          setState(() {
            isLoading = false; // Hide loading spinner
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please upload your child's image."),
            backgroundColor: Colors.red,
          ));
          return;
        }

        if (role == 'therapist' &&
            (_nationalProofImage == null || _TherapistImage == null)) {
          setState(() {
            isLoading = false; // Hide loading spinner
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Please upload your national proof and therapist image."),
            backgroundColor: Colors.red,
          ));
          return;
        }

        // Register user with Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        String userId = userCredential.user!.uid;

        if (role == 'parent') {
          String childImageUrl = "";
          String childId = uuid.v4();
          childname = childNameController.text.trim();
          childAge = int.parse(childAgeController.text.trim());
          parentPhonenumber =
              int.parse(parentPhoneNumberController.text.trim());
          childInterest = childInterestController.text.trim();

          if (_childImage != null) {
            // Upload child image to Firebase Storage and get the URL
            childImageUrl =
                await uploadImageToStorage(_childImage!, 'child_images');
          }

          // Save child details to Firestore
          await FirebaseFirestore.instance
              .collection('child')
              .doc(childId)
              .set({
            'childId': childId,
            'name': childname,
            'age': childAge,
            'childInterest': childInterest,
            'childPhoto': childImageUrl,
            'userId': userId,
            'parentnumber': parentPhonenumber,
            'therapistId': '',
            'assigned': false,
          });
        } else if (role == 'therapist') {
          String nationalProofUrl = "";
          String TherpistImageUrl = "";
          therapistPhonenumber =
              int.parse(therapistPhoneNumberController.text.trim());

          if (_nationalProofImage != null) {
            // Upload national proof to Firebase Storage and get the URL
            nationalProofUrl = await uploadImageToStorage(
                _nationalProofImage!, 'national_proofs');
          }
          if (_TherapistImage != null) {
            // Upload national proof to Firebase Storage and get the URL
            TherpistImageUrl = await uploadImageToStorage(
                _TherapistImage!, 'Therapists_images');
          }

          // Save therapist details to Firestore
          await FirebaseFirestore.instance
              .collection('therapist')
              .doc(userId)
              .set({
            'bio': bio,
            'nationalid': nationalid,
            'nationalproof': nationalProofUrl,
            'therapistimage': TherpistImageUrl,
            'status': status,
            'therapistnumber': therapistPhonenumber,
            'therapistid': userId,
            'userid': userId
          });
        }

        // Save user details to Firestore
        await FirebaseFirestore.instance.collection('user').doc(userId).set({
          'email': email,
          'password': password,
          'role': role,
          'userid': userId,
          'username': username,
          'biometricEnabled': false,
        });
        // Prompt for biometric authentication
        bool enableBiometric = await LocalAuth
            .hasBiometrics(); // Check if device supports biometrics
        if (enableBiometric) {
          bool biometricEnabled =
              await LocalAuth.authenticate(); // Attempt biometric registration
          if (biometricEnabled) {
            await FirebaseFirestore.instance
                .collection('user')
                .doc(userId)
                .update({
              'biometricEnabled': true
            }); // Update Firestore to enable biometrics
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Biometric authentication enabled successfully."),
            ));
          }
        }

        // Save session data using SessionProvider
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);
        await sessionProvider.saveSession(userId, role);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
          "Registered Successfully",
          style: TextStyle(fontSize: 20.0),
        )));

        // Navigate based on Role
        if (role == 'parent') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const Navigationpage()));
        } else if (role == 'therapist') {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => const LogIn()));

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Your account is pending approval. Please wait until the admin approves your request."),
            backgroundColor: Colors.orangeAccent,
          ));
        } else if (role == 'admin') {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const DashBoard()));
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          isLoading = false; // Hide loading spinner
        });
        if (e.code == 'weak-password') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Password Provided is too Weak",
                style: TextStyle(fontSize: 18.0),
              )));
        } else if (e.code == "email-already-in-use") {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Account Already exists",
                style: TextStyle(fontSize: 18.0),
              )));
        } else {
          print("Error: ${e.toString()}");
        }
      } catch (e) {
        print("Error: ${e.toString()}");
      }
    }
    setState(() {
      isLoading = false; // Hide loading spinner when done
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Up"),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme(); // Toggle the theme
            },
          ),
        ],
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      // Use the `isLoading` flag to control what is shown
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(), // Show loading spinner
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formkey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: usernamecontroller,
                        decoration: InputDecoration(
                            labelText: "Username",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30))),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter Username' : null,
                      ),
                      const SizedBox(height: 20.0),
                      TextFormField(
                        controller: emailcontroller,
                        decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30))),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter Email' : null,
                      ),
                      const SizedBox(height: 20.0),
                      TextFormField(
                        controller: passwordcontroller,
                        obscureText: true,
                        decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30))),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter Password' : null,
                      ),
                      const SizedBox(height: 20.0),
                      DropdownButtonFormField(
                        value: role,
                        items: ['parent', 'therapist']
                            .map((role) => DropdownMenuItem(
                                value: role, child: Text(role)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => role = value.toString()),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                      if (role == 'parent') ...[
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: parentPhoneNumberController,
                          decoration: InputDecoration(
                            labelText: "Parent Phone Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter parent phone number';
                            }
                            if (value.length != 11) {
                              return 'Phone number must be exactly 11 digits';
                            }
                            if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                              return 'Phone number must contain only numbers';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: childNameController,
                          decoration: InputDecoration(
                              labelText: "Child Name",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30))),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter Child Name' : null,
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: childAgeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: "Child Age",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30))),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter Child Age';
                            }
                            int? age = int.tryParse(value);
                            if (age == null || age < 3 || age > 12) {
                              return 'Age must be between 3 and 12';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: childInterestController,
                          decoration: InputDecoration(
                              labelText: "Child Interest",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30))),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter Child Interest' : null,
                        ),
                        const SizedBox(height: 20.0),
                        const Text("Child Image"),
                        GestureDetector(
                          onTap: pickChildImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _childImage != null
                                ? FileImage(_childImage!)
                                : null,
                            child: _childImage == null
                                ? const Icon(Icons.camera_alt, size: 50)
                                : null,
                          ),
                        ),
                      ],
                      if (role == 'therapist') ...[
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: therapistPhoneNumberController,
                          decoration: InputDecoration(
                            labelText: "Therapist Phone",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter Therapist Phone Number';
                            }
                            if (value.length != 11) {
                              return 'Phone number must be exactly 11 digits';
                            }
                            if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                              return 'Phone number must contain only numbers';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: bioController,
                          decoration: InputDecoration(
                            labelText: "Bio",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter a short bio' : null,
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: nationalIdController,
                          decoration: InputDecoration(
                            labelText: "National ID",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter National ID';
                            }
                            if (value.length != 14) {
                              return 'National ID must be exactly 14 digits';
                            }
                            if (!RegExp(r'^\d{14}$').hasMatch(value)) {
                              return 'National ID must contain only numbers';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        const Text("National Proof"),
                        GestureDetector(
                          onTap: pickNationalProofImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _nationalProofImage != null
                                ? FileImage(_nationalProofImage!)
                                : null,
                            child: _nationalProofImage == null
                                ? const Icon(Icons.camera_alt, size: 50)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        const Text("Therapist Image"),
                        GestureDetector(
                          onTap: pickTherapistImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _TherapistImage != null
                                ? FileImage(_TherapistImage!)
                                : null,
                            child: _TherapistImage == null
                                ? const Icon(Icons.camera_alt, size: 50)
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30.0),
                      ElevatedButton(
                        onPressed: registration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Register",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LogIn()));
                        },
                        child: const Text(
                          "Already have an account? Log In",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 16.0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
