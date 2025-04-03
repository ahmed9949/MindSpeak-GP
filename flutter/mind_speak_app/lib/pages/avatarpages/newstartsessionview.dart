// lib/views/start_session_view.dart

import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/sessioncontroller.dart';
import 'package:mind_speak_app/pages/avatarpages/voicechatview.dart';
import 'package:provider/provider.dart';
 import 'package:mind_speak_app/models/sessionmodel.dart';
 import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StartSessionView extends StatefulWidget {
  const StartSessionView({super.key});

  @override
  _StartSessionViewState createState() => _StartSessionViewState();
}

class _StartSessionViewState extends State<StartSessionView> {
  bool isLoading = false;
  String? errorMessage;
  Map<String, dynamic>? childData;

  late SessionController sessionController;
  late GenerativeModel generativeModel;

  @override
  void initState() {
    super.initState();
    // Obtain the SessionController from Provider.
    sessionController = Provider.of<SessionController>(context, listen: false);
    // Initialize the generative model using the API key from environment variables.
    generativeModel = GenerativeModel(
      model: 'gemini-pro',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
    );
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Replace this with actual logic (e.g., from a SessionProvider) to get the child's ID.
      const String childId = "child123";
      final data = await sessionController.fetchChildData(childId);
      setState(() {
        childData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _generateInitialPrompt(Map<String, dynamic> childData) {
    final name = childData['name'] ?? '';
    final age = childData['age']?.toString() ?? '';
    final interest = childData['childInterest'] ?? '';
    return '''
Act as a therapist for children with autism, trying to enhance communication skills.

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

  Future<void> _startSession() async {
    if (childData == null) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final prompt = _generateInitialPrompt(childData!);
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      // Create a new session model.
      final sessionData = SessionData(
        sessionId: sessionId,
        childId: childData!['childId'] ?? "child123",
        therapistId: childData!['therapistId'] ?? "therapist123",
        startTime: DateTime.now(),
        conversation: [],
      );
      // Use the SessionController to save the new session.
      await sessionController.startNewSession(sessionData);
      
      // Navigate to the VoiceChatView, passing along the initial prompt.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceChatView(
            childData: childData!,
            initialPrompt: prompt,
            initialResponse: "", // Optionally, you could call ChatController to pre-fetch an AI response.
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Start Therapy Session"),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMessage != null
                ? Text("Error: $errorMessage")
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Welcome, ${childData?['name'] ?? 'Child'}"),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startSession,
                        child: const Text("Start Session"),
                      ),
                    ],
                  ),
      ),
    );
  }
}
