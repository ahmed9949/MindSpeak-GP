import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mind_speak_app/Repositories/progressquestionrepository.dart';
import 'package:mind_speak_app/components/splashscreen.dart';
import 'package:mind_speak_app/controllers/progresscontroller.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/avatarservice/conversationsetup.dart';
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
        ChangeNotifierProvider(
          create: (_) => ProgressController(FirebaseProgressRepository()),
        ),
        ...ConversationModule.providers(),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
