// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mind_speak_app/forgot_password.dart';
import 'package:mind_speak_app/homepage.dart';
import 'package:mind_speak_app/navigationpage.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
import 'package:mind_speak_app/signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  String email = "", password = "";
  bool isLoading = false; // For loading indicator

  TextEditingController mailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  final _formkey = GlobalKey<FormState>();

//   userLogin() async {
//   if (!_formkey.currentState!.validate()) {
//     // If the form is not valid, do not proceed.
//     return;
//   }

//   setState(() {
//     email = mailcontroller.text.trim(); // Ensure to trim inputs
//     password = passwordcontroller.text.trim();
//   });

//   try {
//     await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//       backgroundColor: Colors.green,
//       content: Text(
//         "Logged in Successfully",
//         style: TextStyle(fontSize: 18.0),
//       )
//     ));
//     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Navigationpage())); // Consider using pushReplacement to avoid back navigation to login screen.
//   } on FirebaseAuthException catch (e) {
//     String errorMessage = 'Username or password is Wrong';
//     if (e.code == 'user-not-found') {
//       errorMessage = "No User Found for that Email";
//     } else if (e.code == 'wrong-password') {
//       errorMessage = "Wrong Password Provided by User";
//     } else if (e.code == 'invalid-email') {
//       errorMessage = "Email address is invalid";
//     }

//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       backgroundColor: Colors.orangeAccent,
//       content: Text(
//         errorMessage,
//         style: const TextStyle(fontSize: 18.0),
//       )
//     ));
//   } catch (e) {
//     // Catch other exceptions that are not FirebaseAuthException
//     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//       backgroundColor: Colors.redAccent,
//       content: Text(
//         "Failed to log in",
//         style: TextStyle(fontSize: 18.0),
//       )
//     ));
//   }
// }

  Future<void> userLogin() async {
    // Validate form inputs
    if (!_formkey.currentState!.validate()) return;

    setState(() {
      isLoading = true; // Show loading indicator
    });

    try {
      // Trim input values
      email = mailcontroller.text.trim();
      password = passwordcontroller.text.trim();

      // Firebase authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Fetch user data from Firestore
      User? user = userCredential.user;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(user!.uid)
          .get();

      // Get role from Firestore
      String role = userDoc['role']; // Fetch role from database

      // Navigate based on role
      if (role == 'parent') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const Navigationpage()), // Parent screen
        );
      } else if (role == 'therapist') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => DoctorDashboard()), // Therapist screen
        );
      } else {
        throw Exception("Unknown role"); // Handle unknown roles
      }

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          "Logged in Successfully",
          style: TextStyle(fontSize: 18.0),
        ),
      ));
    } on FirebaseAuthException catch (e) {
      // Firebase authentication errors
      String errorMessage = 'Invalid credentials';
      if (e.code == 'user-not-found') {
        errorMessage = "No User Found for that Email";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Wrong Password Provided by User";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid Email Address";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.orangeAccent,
        content: Text(
          errorMessage,
          style: const TextStyle(fontSize: 18.0),
        ),
      ));
    } catch (e) {
      // Other errors
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          "Failed to log in",
          style: TextStyle(fontSize: 18.0),
        ),
      ));
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        // Added SingleChildScrollView
        child: Container(
          child: Column(
            children: [
              SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Image.asset(
                    "assets/car.PNG",
                    fit: BoxFit.cover,
                  )),
              const SizedBox(
                height: 30.0,
              ),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please Enter E-mail';
                            }
                            return null;
                          },
                          controller: mailcontroller,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Email",
                              hintStyle: TextStyle(
                                  color: Color(0xFFb2b7bf), fontSize: 18.0)),
                        ),
                      ),
                      const SizedBox(
                        height: 30.0,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2.0, horizontal: 30.0),
                        decoration: BoxDecoration(
                            color: const Color(0xFFedf0f8),
                            borderRadius: BorderRadius.circular(30)),
                        child: TextFormField(
                          controller: passwordcontroller,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please Enter Password';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Password",
                              hintStyle: TextStyle(
                                  color: Color(0xFFb2b7bf), fontSize: 18.0)),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(
                        height: 30.0,
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_formkey.currentState!.validate()) {
                            setState(() {
                              email = mailcontroller.text;
                              password = passwordcontroller.text;
                            });
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
                            ))),
                      ),
                      const SizedBox(
                        height: 20.0,
                      ),
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
                      const SizedBox(
                        height: 30.0,
                      ),
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
                      const SizedBox(
                        height: 40.0,
                      ),
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
                      )
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
