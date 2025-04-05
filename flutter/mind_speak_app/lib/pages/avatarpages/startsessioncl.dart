// // lib/views/session/start_session_page.dart
// import 'package:flutter/material.dart';
// import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
// import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
// import 'package:mind_speak_app/pages/avatarpages/sessionviewcl.dart';
// import 'package:mind_speak_app/providers/session_provider.dart'; 
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class StartSessionPage extends StatefulWidget {
//   const StartSessionPage({super.key});

//   @override
//   State<StartSessionPage> createState() => _StartSessionPageState();
// }

// class _StartSessionPageState extends State<StartSessionPage> {
//   bool _isLoading = false;
//   String? _errorMessage;
//   late GenerativeModel _model;
//   late SessionRepository _sessionRepository;
//   late SessionController _sessionController;
//   late SessionAnalyzerController _analyzerController;

//   @override
//   void initState() {
//     super.initState();
//     _initializeServices();
//   }

//   void _initializeServices() {
//     // Initialize AI model
//     final apiKey = dotenv.env['GEMINI_API_KEY']!;
//     _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);

//     // Initialize repository
//     _sessionRepository = FirebaseSessionRepository();

//     // Initialize controllers
//     _sessionController = SessionController(_sessionRepository);
//     _analyzerController = SessionAnalyzerController(_model);
//   }

//   Future<Map<String, dynamic>?> _fetchChildData(String childId) async {
//     try {
//       DocumentSnapshot childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         setState(() => _errorMessage = 'Child data not found');
//         return null;
//       }

//       return childDoc.data() as Map<String, dynamic>;
//     } catch (e) {
//       setState(() => _errorMessage = 'Error fetching child data: $e');
//       return null;
//     }
//   }

//   String _generateInitialPrompt(Map<String, dynamic> childData) {
//     final name = childData['name'] ?? '';
//     final age = childData['age']?.toString() ?? '';
//     final interest = childData['childInterest'] ?? '';

//     return '''
// Act as a therapist for children with autism, trying to enhance communication skills.
// talk with him in egyption arabic

// Child Information:
// - Name: $name
// - Age: $age
// - Main Interest: $interest

// Task:
// You are a therapist helping this child improve their communication skills. 
// 1. Start by engaging with their interest in $interest
// 2. Gradually expand the conversation beyond this interest
// 3. Keep responses short and clear
// 4. Use positive reinforcement
// 5. Be patient and encouraging
// 6. Speak in Arabic

// Please provide the initial therapeutic approach and first question you'll ask the child, focusing on their interest in $interest.
// Remember to: 
// - Keep responses under 2 sentences
// - Be warm and encouraging
// - Start with their comfort zone ($interest)
// - Later guide them to broader topics
// ''';
//   }

//   Future<void> _startSession() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       // Get child ID directly from the SessionProvider
//       final childId = Provider.of<SessionProvider>(context, listen: false).childId;
//       if (childId == null || childId.isEmpty) {
//         throw Exception('No child selected');
//       }

//       final childData = await _fetchChildData(childId);
//       if (childData == null) {
//         throw Exception('Failed to fetch child data');
//       }

//       // Get therapist ID from child data
//       final String therapistId = childData['therapistId'] ?? '';

//       // Start the session using controller
//       await _sessionController.startSession(childId, therapistId);

//       // Generate initial AI prompt and response
//       final prompt = _generateInitialPrompt(childData);
//       final chat = _model.startChat();
//       final response = await chat.sendMessage(Content.text(prompt));

//       if (response.text == null) {
//         throw Exception('Failed to generate initial response');
//       }

//       // Save the initial therapist message
//       await _sessionController.addTherapistMessage(response.text!);

//       if (mounted) {
//         // Navigate to the session view with all controllers
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => MultiProvider(
//               providers: [
//                 ChangeNotifierProvider.value(value: _sessionController),
//                 Provider.value(value: _analyzerController),
//               ],
//               child: SessionView(
//                 initialPrompt: prompt,
//                 initialResponse: response.text!,
//                 childData: childData,
//               ),
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Error starting session: $e';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Start Therapy Session'),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (_isLoading)
//                 const CircularProgressIndicator()
//               else
//                 ElevatedButton.icon(
//                   onPressed: _startSession,
//                   icon: const Icon(Icons.play_circle_outline),
//                   label: const Text('Start Session'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 32,
//                       vertical: 16,
//                     ),
//                   ),
//                 ),
//               if (_errorMessage != null)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 16),
//                   child: Text(
//                     _errorMessage!,
//                     style: const TextStyle(color: Colors.red),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




// lib/views/session/start_session_page.dart
import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/pages/avatarpages/sessionviewcl.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
 
class StartSessionPage extends StatefulWidget {
  const StartSessionPage({super.key});

  @override
  State<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends State<StartSessionPage> {
  bool _isLoading = false;
  String? _errorMessage;
  late ChatGptModel _model;
  late SessionRepository _sessionRepository;
  late SessionController _sessionController;
  late SessionAnalyzerController _analyzerController;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    final apiKey = dotenv.env['OPEN_AI_API_KEY']!;
    _model = ChatGptModel(apiKey: apiKey);
    _sessionRepository = FirebaseSessionRepository();
    _sessionController = SessionController(_sessionRepository);
    _analyzerController = SessionAnalyzerController(_model);
  }

  Future<Map<String, dynamic>?> _fetchChildData(String childId) async {
    try {
      DocumentSnapshot childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        setState(() => _errorMessage = 'Child data not found');
        return null;
      }

      return childDoc.data() as Map<String, dynamic>;
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching child data: $e');
      return null;
    }
  }

  String _generateInitialPrompt(Map<String, dynamic> childData) {
    final name = childData['name'] ?? '';
    final age = childData['age']?.toString() ?? '';
    final interest = childData['childInterest'] ?? '';

    return '''
Act as a therapist for children with autism, trying to enhance communication skills.
Talk with the child in Egyptian Arabic.

Child Information:
- Name: $name
- Age: $age
- Main Interest: $interest

Task:
You are a therapist helping this child improve their communication skills.
1. Start by engaging with their interest in $interest
2. Gradually expand the conversation beyond this interest
3. Keep responses short and clear
4. Use positive reinforcement
5. Be patient and encouraging
6. Speak in Arabic

Please provide the initial therapeutic approach and first question you'll ask the child, focusing on their interest in $interest.
Remember to:
- Keep responses under 2 sentences
- Be warm and encouraging
- Start with their comfort zone ($interest)
- Later guide them to broader topics
''';
  }

  // Future<void> _startSession() async {
    
  //   setState(() {
  //     _isLoading = true;
  //     _errorMessage = null;
  //   });

  //   try {
  //     final childId = Provider.of<SessionProvider>(context, listen: false).childId;
  //     if (childId == null || childId.isEmpty) {
  //       throw Exception('No child selected');
  //     }

  //     final childData = await _fetchChildData(childId);
  //     if (childData == null) {
  //       throw Exception('Failed to fetch child data');
  //     }

  //     final String therapistId = childData['therapistId'] ?? '';
  //     await _sessionController.startSession(childId, therapistId);

  //     final prompt = _generateInitialPrompt(childData);
  //     final responseText = await _model.sendMessage(prompt);

  //     if (responseText.isEmpty) {
  //       throw Exception('Failed to generate initial response');
  //     }

  //     await _sessionController.addTherapistMessage(responseText);

  //     if (mounted) {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => MultiProvider(
  //             providers: [
  //               ChangeNotifierProvider.value(value: _sessionController),
  //               Provider.value(value: _analyzerController),
  //             ],
  //             child: SessionView(
  //               initialPrompt: prompt,
  //               initialResponse: responseText,
  //               childData: childData,
  //             ),
  //           ),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _errorMessage = 'Error starting session: $e';
  //     });
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

Future<void> _startSession() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final childId = Provider.of<SessionProvider>(context, listen: false).childId;
    if (childId == null || childId.isEmpty) {
      throw Exception('No child selected');
    }

    final childData = await _fetchChildData(childId);
    if (childData == null) {
      throw Exception('Failed to fetch child data');
    }

    final String therapistId = childData['therapistId'] ?? '';
    await _sessionController.startSession(childId, therapistId);

    final prompt = _generateInitialPrompt(childData);
    
    // Clear any previous conversation history
    _model.clearConversation();
    
    // Send initial prompt with child data for context
    final responseText = await _model.sendMessage(prompt, childData: childData);

    if (responseText.isEmpty) {
      throw Exception('Failed to generate initial response');
    }

    await _sessionController.addTherapistMessage(responseText);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _sessionController),
              Provider.value(value: _analyzerController),
            ],
            child: SessionView(
              initialPrompt: prompt,
              initialResponse: responseText,
              childData: childData,
            ),
          ),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error starting session: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Therapy Session'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Start Session'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
