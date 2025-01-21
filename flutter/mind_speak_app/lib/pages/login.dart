import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart'; // Import for hashing passwords
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mind_speak_app/components/navigationpage.dart';
import 'package:mind_speak_app/pages/DashBoard.dart';
import 'package:mind_speak_app/pages/carsfrom.dart';
import 'package:mind_speak_app/pages/doctor_dashboard.dart';
import 'package:mind_speak_app/pages/forgot_password.dart';
import 'package:mind_speak_app/pages/homepage.dart';
import 'package:mind_speak_app/pages/signup.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/doctor_dashboard_service.dart';
import 'package:mind_speak_app/service/local_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mind_speak_app/service/local_auth_service.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  String email = "", password = "";
  bool isLoading = false;
  final bool _isAuthenticated = false;

  TextEditingController mailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  final DoctorDashboardService _doctorServices = DoctorDashboardService();

  final _formkey = GlobalKey<FormState>();

  // *Hashing Function*
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hashed = sha256.convert(bytes);
    return hashed.toString();
  }

  signInWithGoogle() async {
    GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken, idToken: googleAuth?.idToken);
    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    if (userCredential.user != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const HomePage()));
    }
  }

  Future<void> userLogin() async {
    if (!_formkey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      email = mailcontroller.text.trim();
      String enteredPassword = passwordcontroller.text.trim();
      String hashedEnteredPassword = hashPassword(enteredPassword);

      // Fetch user from Firestore by email
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception("No user found with this email.");
      }

      var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
      String storedPassword = userData['password'];
      String role = userData['role'];
      bool isApproved = userData['status'] ?? false;
      bool biometricEnabled = userData['biometricEnabled'] ?? false;
      String userId = userSnapshot.docs.first.id;

      if (hashedEnteredPassword == storedPassword) {
        // Save session data using SessionProvider
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);
        await sessionProvider.saveSession(userSnapshot.docs.first.id, role);

        if (biometricEnabled) {
          // Authenticate using biometrics
          bool authenticated = await LocalAuth.authenticate();

          if (!authenticated) {
            throw Exception("Biometric authentication failed.");
          }
        } else {
          // Prompt to enable biometrics if not already enabled
          bool enableBiometric = await LocalAuth.linkBiometrics();
          if (enableBiometric) {
            await FirebaseFirestore.instance
                .collection('user')
                .doc(userId)
                .update({'biometricEnabled': true});
          }
        }
        if (role == 'parent') {
          // Fetch child data for the current user
          QuerySnapshot childSnapshot = await FirebaseFirestore.instance
              .collection('child')
              .where('userId', isEqualTo: userSnapshot.docs.first.id)
              .get();

          if (childSnapshot.docs.isNotEmpty) {
            final childId = childSnapshot.docs.first['childId'];

            // Check if the Cars form is completed
            QuerySnapshot carsSnapshot = await FirebaseFirestore.instance
                .collection('Cars')
                .where('childId', isEqualTo: childId)
                .get();

            if (carsSnapshot.docs.isNotEmpty) {
              final carsData =
                  carsSnapshot.docs.first.data() as Map<String, dynamic>;
              bool formStatus = carsData['status'] ?? false;

              if (formStatus) {
                // Navigate to HomePage if Cars form is completed
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              } else {
                // Navigate to carsform if Cars form is not completed
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const carsform()),
                );
              }
            } else {
              // Navigate to carsform if no Cars form exists
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const carsform()),
              );
            }
          } else {
            throw Exception("No child associated with this parent.");
          }
        } else if (role == 'therapist') {
          if (isApproved) {
            try {
              Map<String, dynamic> therapistInfo = await _doctorServices
                  .getTherapistInfo(userSnapshot.docs.first.id);
              Map<String, dynamic> userInfo =
                  await _doctorServices.getUserInfo(userSnapshot.docs.first.id);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorDashboard(
                    sessionId: userSnapshot.docs.first.id,
                    therapistInfo: therapistInfo,
                    userInfo: userInfo,
                  ),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 18.0),
                ),
              ));
            }
          } else {
            throw Exception("Your account is not yet approved by the admin.");
          }
        } else if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashBoard()),
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

  // void _authenticateWithBiometrics(String userId) async {
  //   try {
  //     // Authenticate using biometrics
  //     bool authenticated = await LocalAuth.authenticate();

  //     if (authenticated) {
  //       // Get current user data from Firestore
  //       QuerySnapshot userSnapshot = await FirebaseFirestore.instance
  //           .collection('user')
  //           .where('biometricEnabled', isEqualTo: true)
  //           .get();

  //       if (userSnapshot.docs.isNotEmpty) {
  //         var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
  //         String role = userData['role'];
  //         bool isApproved = userData['status'] ?? false;

  //         // Navigate based on role
  //         if (role == 'parent') {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (context) => const HomePage()),
  //           );
  //         } else if (role == 'therapist' && isApproved) {
  //           try {
  //             Map<String, dynamic> therapistInfo = await _doctorServices
  //                 .getTherapistInfo(userSnapshot.docs.first.id);
  //             Map<String, dynamic> userInfo =
  //                 await _doctorServices.getUserInfo(userSnapshot.docs.first.id);
  //             Navigator.pushReplacement(
  //               context,
  //               MaterialPageRoute(
  //                   builder: (context) => DoctorDashboard(
  //                       sessionId: userSnapshot
  //                           .docs.first.id, // Pass the sessionId (user ID)
  //                       therapistInfo:
  //                           therapistInfo, // Pass the therapist information
  //                       userInfo: userInfo)),
  //             );
  //           } catch (e) {
  //             // Handle errors
  //             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //               backgroundColor: Colors.redAccent,
  //               content: Text(
  //                 e.toString(),
  //                 style: const TextStyle(fontSize: 18.0),
  //               ),
  //             ));
  //           }
  //         } else if (role == 'admin') {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (context) => const DashBoard()),
  //           );
  //         } else {
  //           throw Exception("Your account is not yet approved.");
  //         }
  //       } else {
  //         throw Exception(
  //             "No user found with biometric authentication enabled.");
  //       }
  //     } else {
  //       throw Exception("Biometric authentication failed.");
  //     }
  //   } catch (e) {
  //     // Show error message
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   }
  // }

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
    body: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Adjusted padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: MediaQuery.of(context).size.height * 0.2, // Adjusted height
                      child: Image.asset(
                        "assets/logo.webp",
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Expanded(
                      child: Form(
                        key: _formkey,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2.0, horizontal: 30.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFedf0f8),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: TextFormField(
                                validator: (value) =>
                                    value!.isEmpty ? 'Please enter E-mail' : null,
                                controller: mailcontroller,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Email",
                                  hintStyle: TextStyle(
                                      color: Color(0xFFb2b7bf), fontSize: 18.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2.0, horizontal: 30.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFedf0f8),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: TextFormField(
                                controller: passwordcontroller,
                                validator: (value) =>
                                    value!.isEmpty ? 'Please enter Password' : null,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Password",
                                  hintStyle: TextStyle(
                                      color: Color(0xFFb2b7bf), fontSize: 18.0),
                                ),
                                obscureText: true,
                              ),
                            ),
                            const SizedBox(height: 20.0),
                            GestureDetector(
                              onTap: () {
                                if (_formkey.currentState!.validate()) {
                                  userLogin();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 13.0, horizontal: 30.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF273671),
                                  borderRadius: BorderRadius.circular(30),
                                ),
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
                                    builder: (context) => const ForgotPassword(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                    color: Color(0xFF8c8e98),
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: signInWithGoogle,
                                  child: Image.asset(
                                    "assets/google.png",
                                    height: 45,
                                    width: 45,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 20.0),
                                Image.asset(
                                  "assets/apple1.png",
                                  height: 50,
                                  width: 50,
                                  fit: BoxFit.cover,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20.0),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final authenticated =
                                    await LocalAuth.authenticate();
                                if (authenticated) {
                                  userLogin();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Biometric authentication failed!')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Login with Biometrics'),
                            ),
                            const SizedBox(height: 20.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                      color: Color(0xFF8c8e98),
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 5.0),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SignUp(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "SignUp",
                                    style: TextStyle(
                                        color: Color(0xFF273671),
                                        fontSize: 15.0,
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
          ),
        );
      },
    ),
  );
}

}
