import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/pages/avatarpages/sessionviewcl.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
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

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final childId =
          Provider.of<SessionProvider>(context, listen: false).childId;
      if (childId == null || childId.isEmpty) {
        throw Exception('No child selected');
      }

      final childData = await _fetchChildData(childId);
      if (childData == null) {
        throw Exception('Failed to fetch child data.');
      }

      final therapistId = childData['therapistId'] ?? '';
      if (therapistId.isEmpty) {
        throw Exception('No therapist assigned to this child.');
      }

      await _sessionController.startSession(childId, therapistId);

      final prompt = _generateInitialPrompt(childData);
      debugPrint(
          'Sending initial prompt to API: ${prompt.substring(0, min(100, prompt.length))}...');

      _model.clearConversation();

      final responseText =
          await _model.sendMessage(prompt, childData: childData);

      debugPrint('API response received: $responseText');

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
                Provider.value(value: _model),
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
      debugPrint('❌ Error starting session: $e');
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    return Theme(
      data: themeProvider.currentTheme,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Start Therapy Session'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[900]!, Colors.black]
                    : [primaryColor, primaryColor.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
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
                      backgroundColor:
                          isDark ? Colors.grey[800] : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}
