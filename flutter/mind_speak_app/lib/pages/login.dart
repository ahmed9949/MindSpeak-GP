// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart'; // Import for hashing passwords
import 'package:mind_speak_app/components/navigationpage.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
import 'package:mind_speak_app/pages/forgot_password.dart';
import 'package:mind_speak_app/pages/signup.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  String email = "", password = "";
  bool isLoading = false;

  TextEditingController mailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  final _formkey = GlobalKey<FormState>();

  // *Hashing Function*
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  Future<void> userLogin() async {
    if (!_formkey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Trim input values
      email = mailcontroller.text.trim();
      String enteredPassword = passwordcontroller.text.trim();
      String hashedEnteredPassword =
          hashPassword(enteredPassword); // Hash input password

      // Fetch user data from Firestore
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception("No user found with this email.");
      }

      // Retrieve user data
      var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
      String storedPassword =
          userData['password']; // Hashed password from Firestore
      String role = userData['role']; // User role

      // Compare hashed passwords
      if (hashedEnteredPassword == storedPassword) {
        // Navigate based on role
        if (role == 'parent') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Navigationpage()),
          );
        } else if (role == 'therapist') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DoctorDashboard()),
          );
        } else if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashBoard()),
          );
        } else {
          throw Exception("Unknown role detected.");
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Logged in Successfully",
            style: TextStyle(fontSize: 18.0),
          ),
        ));
      } else {
        throw Exception("Incorrect password.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          e.toString(),
          style: const TextStyle(fontSize: 18.0),
        ),
      ));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
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
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Image.asset(
                  "assets/logo.webp",
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 30.0),
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Form(
                  key: _formkey,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2.0, horizontal: 30.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFFedf0f8),
                            borderRadius: BorderRadius.circular(30)),
                        child: TextFormField(
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter E-mail' : null,
                          controller: mailcontroller,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Email",
                              hintStyle: TextStyle(
                                  color: Color(0xFFb2b7bf), fontSize: 18.0)),
                        ),
                      ),
                      const SizedBox(height: 30.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2.0, horizontal: 30.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFFedf0f8),
                            borderRadius: BorderRadius.circular(30)),
                        child: TextFormField(
                          controller: passwordcontroller,
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter Password' : null,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Password",
                              hintStyle: TextStyle(
                                  color: Color(0xFFb2b7bf), fontSize: 18.0)),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(height: 30.0),
                      GestureDetector(
                        onTap: () {
                          if (_formkey.currentState!.validate()) {
                            userLogin();
                          }
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13.0, horizontal: 30.0),
                          decoration: BoxDecoration(
                              color: const Color(0xFF273671),
                              borderRadius: BorderRadius.circular(30)),
                          child: const Center(
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPassword()));
                        },
                        child: const Text("Forgot Password?",
                            style: TextStyle(
                                color: Color(0xFF8c8e98),
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(
                        height: 40.0,
                      ),
                      const Text(
                        "or LogIn with",
                        style: TextStyle(
                            color: Color(0xFF273671),
                            fontSize: 22.0,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 30.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/google.png",
                            height: 45,
                            width: 45,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 30.0,
                          ),
                          Image.asset(
                            "assets/apple1.png",
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?",
                              style: TextStyle(
                                  color: Color(0xFF8c8e98),
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(
                            width: 5.0,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const SignUp()));
                            },
                            child: const Text(
                              "SignUp",
                              style: TextStyle(
                                  color: Color(0xFF273671),
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
