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
import 'providers/color_provider.dart';
import 'package:mind_speak_app/service/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await dotenv.load(fileName: "assets/.env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (context) => ColorProvider()), // ✅ Add this
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
    NotificationService.initialize(context);
    return Consumer2<ThemeProvider, ColorProvider>(
      builder: (context, themeProvider, colorProvider, _) {
        final baseTheme =
            themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light();

        final updatedTheme = baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: colorProvider.primaryColor,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorProvider.primaryColor,
            ),
          ),
          appBarTheme: baseTheme.appBarTheme.copyWith(
            backgroundColor: colorProvider.primaryColor,
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: updatedTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}
