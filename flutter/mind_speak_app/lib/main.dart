import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mind_speak_app/pages/splashscreen.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).isDarkMode
          ? ThemeData.dark()
          : ThemeData.light(),
      home: SplashScreen(),
    );
  }
}
