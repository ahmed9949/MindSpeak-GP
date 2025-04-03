// lib/screens/start_session_page.dart

import 'package:flutter/material.dart';
import 'package:mind_speak_app/pages/avatarpages/VoiceChat3DModelPage.dart';
import 'package:mind_speak_app/pages/avatarpages/newstartsessionview.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mind_speak_app/providers/session_provider.dart';

class StartSessionPage extends StatefulWidget {
  const StartSessionPage({super.key});

  @override
  State<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends State<StartSessionPage> {
  bool _isLoading = false;
  String? _errorMessage;
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _initGenerativeModel();
  }

  void _initGenerativeModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
  }

  Future<Map<String, dynamic>?> _fetchChildData() async {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    if (!sessionProvider.isLoggedIn || sessionProvider.childId == null) {
      setState(() => _errorMessage = 'No child data available');
      return null;
    }

    try {
      DocumentSnapshot childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(sessionProvider.childId)
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
talk with him in egyption arabic

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final childData = await _fetchChildData();
      if (childData == null) {
        setState(() => _isLoading = false);
        return;
      }

      final prompt = _generateInitialPrompt(childData);
      final chat = _model.startChat();
      final response = await chat.sendMessage(Content.text(prompt));

      if (response.text == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to generate initial response';
        });
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VoiceChat3DModelPage(
              childData: childData,
              initialPrompt: prompt,
              initialResponse: response.text!,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error starting session: $e';
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
