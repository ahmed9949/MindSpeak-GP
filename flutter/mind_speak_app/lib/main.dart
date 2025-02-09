import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mind_speak_app/components/splashscreen.dart';
import 'package:mind_speak_app/pages/sessionservice.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await dotenv.load(fileName: "assets/.env");

  // Initialize services
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (context) => SessionProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => SessionManagerProvider()),
        Provider<IAdminRepository>(
          create: (_) => AdminRepository(),
        ),
        
      ],
      child: const MyApp(),
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
      home: const SplashScreen(),
    );
  }
}
