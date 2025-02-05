import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mind_speak_app/controllers/SignupController.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:provider/provider.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formkey = GlobalKey<FormState>();

  late TextEditingController usernamecontroller;
  late TextEditingController emailcontroller;
  late TextEditingController passwordcontroller;
  late TextEditingController childNameController;
  late TextEditingController childAgeController;
  late TextEditingController childInterestController;
  late TextEditingController nationalIdController;
  late TextEditingController bioController;
  late TextEditingController parentPhoneNumberController;
  late TextEditingController therapistPhoneNumberController;

  String role = "parent";
  File? _childImage;
  File? _nationalProofImage;
  File? _therapistImage;
  bool isLoading = false;

  late SignUpController _signUpController;

  @override
  void initState() {
    super.initState();

    usernamecontroller = TextEditingController();
    emailcontroller = TextEditingController();
    passwordcontroller = TextEditingController();
    childNameController = TextEditingController();
    childAgeController = TextEditingController();
    childInterestController = TextEditingController();
    nationalIdController = TextEditingController();
    bioController = TextEditingController();
    parentPhoneNumberController = TextEditingController();
    therapistPhoneNumberController = TextEditingController();

    _signUpController = SignUpController(
      context: context,
      formKey: _formkey,
      usernameController: usernamecontroller,
      emailController: emailcontroller,
      passwordController: passwordcontroller,
      childNameController: childNameController,
      childAgeController: childAgeController,
      childInterestController: childInterestController,
      nationalIdController: nationalIdController,
      bioController: bioController,
      parentPhoneNumberController: parentPhoneNumberController,
      therapistPhoneNumberController: therapistPhoneNumberController,
      role: role,
      childImage: _childImage,
      nationalProofImage: _nationalProofImage,
      therapistImage: _therapistImage,
    );
  }

  @override
  void dispose() {
    usernamecontroller.dispose();
    emailcontroller.dispose();
    passwordcontroller.dispose();
    childNameController.dispose();
    childAgeController.dispose();
    childInterestController.dispose();
    nationalIdController.dispose();
    bioController.dispose();
    parentPhoneNumberController.dispose();
    therapistPhoneNumberController.dispose();
    super.dispose();
  }

  Future<void> pickChildImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _childImage = pickedImage;
        _signUpController.childImage = pickedImage;
      });
    }
  }

  Future<void> pickNationalProofImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _nationalProofImage = pickedImage;
        _signUpController.nationalProofImage = pickedImage;
      });
    }
  }

  Future<void> pickTherapistImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _therapistImage = pickedImage;
        _signUpController.therapistImage = pickedImage;
      });
    }
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
              themeProvider.toggleTheme();
            },
          ),
        ],
        centerTitle: true,
      ),
      backgroundColor:
          themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
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
                        onChanged: (value) => setState(() {
                          role = value.toString();
                          _signUpController.role = role;
                        }),
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
                            backgroundImage: _therapistImage != null
                                ? FileImage(_therapistImage!)
                                : null,
                            child: _therapistImage == null
                                ? const Icon(Icons.camera_alt, size: 50)
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30.0),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          _signUpController.registration().then((_) {
                            setState(() {
                              isLoading = false;
                            });
                          }).catchError((error) {
                            setState(() {
                              isLoading = false;
                            });
                          });
                        },
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
