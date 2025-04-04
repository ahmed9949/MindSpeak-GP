// // lib/modules/conversation_module.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
// import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';
// import 'package:provider/single_child_widget.dart';

// /// ConversationModule provides a way to set up all dependencies related to the conversation feature.
// /// Works directly with the existing SessionProvider.
// class ConversationModule {
//   /// Creates providers for the conversation feature to be used with MultiProvider
//   static List<SingleChildWidget> providers() {
//     // Initialize the repository
//     final sessionRepository = FirebaseSessionRepository();

//     // Initialize the AI model
//     final apiKey = dotenv.env['GEMINI_API_KEY']!;
//     final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

//     // Create controllers
//     final sessionController = SessionController(sessionRepository);
//     final analyzerController = SessionAnalyzerController(model);

//     return [
//       // Repository providers
//       Provider<SessionRepository>.value(value: sessionRepository),

//       // Controller providers
//       ChangeNotifierProvider<SessionController>.value(value: sessionController),
//       Provider<SessionAnalyzerController>.value(value: analyzerController),
//     ];
//   }

//   /// Creates a new GenerativeModel instance with the configured API key
//   static GenerativeModel createGenerativeModel() {
//     final apiKey = dotenv.env['GEMINI_API_KEY']!;
//     return GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
//   }

//   /// Gets the childId from the SessionProvider
//   static String? getChildId(BuildContext context) {
//     final sessionProvider =
//         Provider.of<SessionProvider>(context, listen: false);
//     return sessionProvider.childId;
//   }

//   /// Gets the userId from the SessionProvider
//   static String? getUserId(BuildContext context) {
//     final sessionProvider =
//         Provider.of<SessionProvider>(context, listen: false);
//     return sessionProvider.userId;
//   }

//   /// Checks if the user is logged in via SessionProvider
//   static bool isLoggedIn(BuildContext context) {
//     final sessionProvider =
//         Provider.of<SessionProvider>(context, listen: false);
//     return sessionProvider.isLoggedIn;
//   }
// }

// lib/modules/conversation_module.dart
import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:provider/single_child_widget.dart';

class ConversationModule {
  static List<SingleChildWidget> providers() {
    final sessionRepository = FirebaseSessionRepository();
    final apiKey = dotenv.env['OPEN_AI_API_KEY']!;
    final model = ChatGptModel(apiKey: apiKey, model: 'gpt-3.5-turbo');

    final sessionController = SessionController(sessionRepository);
    // final analyzerController = SessionAnalyzerController(model);

    return [
      Provider<SessionRepository>.value(value: sessionRepository),
      ChangeNotifierProvider<SessionController>.value(value: sessionController),
      // Provider<SessionAnalyzerController>.value(value: analyzerController),
    ];
  }

  static ChatGptModel createGenerativeModel() {
    final apiKey = dotenv.env['OPEN_AI_API_KEY']!;
    return ChatGptModel(apiKey: apiKey, model: 'gpt-3.5-turbo');
  }

  static String? getChildId(BuildContext context) {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    return sessionProvider.childId;
  }

  static String? getUserId(BuildContext context) {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    return sessionProvider.userId;
  }

  static bool isLoggedIn(BuildContext context) {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    return sessionProvider.isLoggedIn;
  }
}
