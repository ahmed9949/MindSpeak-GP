import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mind_speak_app/Repositories/chatrepository.dart';
import 'package:mind_speak_app/Repositories/detectionrepository.dart';
import 'package:mind_speak_app/Repositories/sessionrepository.dart';
import 'package:mind_speak_app/components/splashscreen.dart';
import 'package:mind_speak_app/controllers/audioncontroller.dart';
import 'package:mind_speak_app/controllers/chatcontroller.dart';
import 'package:mind_speak_app/controllers/detectiondontroller.dart';
import 'package:mind_speak_app/controllers/sessioncontroller.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await dotenv.load(fileName: "assets/.env");


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (context) => SessionProvider()..loadSession()),
        Provider<IAdminRepository>(
          create: (_) => AdminRepository(),
        ),
         Provider<SessionRepository>(create: (_) => SessionRepository()),
        Provider<SessionController>(
          create: (context) => SessionController(
            sessionRepo: Provider.of<SessionRepository>(context, listen: false),
          ),
        ),
        Provider<ChatRepository>(create: (_) => ChatRepository()),
        Provider<ChatController>(
          create: (context) => ChatController(
            chatRepo: Provider.of<ChatRepository>(context, listen: false),
          ),
        ),
        Provider<DetectionRepository>(create: (_) => DetectionRepository()),
        Provider<DetectionController>(
          create: (context) => DetectionController(
            detectionRepo: Provider.of<DetectionRepository>(context, listen: false),
          ),
        ),
        Provider<AudioController>(
          create: (_) => AudioController()..init(),
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
