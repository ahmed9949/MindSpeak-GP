import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:mind_speak_app/components/navigationpage.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay for 3 seconds then navigate based on session status
    Future.delayed(const Duration(seconds: 3), () {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      if (sessionProvider.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Navigationpage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LogIn()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.red], // Gradient colors
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.webp', // Replace with your logo image path
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                'Mind Speak App', // Replace with your app name
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
