// lib/views/voice_chat_view.dart

import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/audioncontroller.dart';
import 'package:mind_speak_app/controllers/chatcontroller.dart';
import 'package:mind_speak_app/controllers/detectiondontroller.dart';
import 'package:provider/provider.dart'; 
import 'package:mind_speak_app/models/sessionmodel.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VoiceChatView extends StatefulWidget {
  final Map<String, dynamic> childData;
  final String initialPrompt;
  final String initialResponse;

  const VoiceChatView({
    Key? key,
    required this.childData,
    required this.initialPrompt,
    required this.initialResponse,
  }) : super(key: key);

  @override
  _VoiceChatViewState createState() => _VoiceChatViewState();
}

class _VoiceChatViewState extends State<VoiceChatView> {
  late ChatController chatController;
  late DetectionController detectionController;
  late AudioController audioController;

  List<ChatMessage> messages = [];
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    chatController = Provider.of<ChatController>(context, listen: false);
    detectionController = Provider.of<DetectionController>(context, listen: false);
    audioController = Provider.of<AudioController>(context, listen: false);

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final generativeModel = GenerativeModel(
      model: 'gemini-pro',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
    );
    try {
      await chatController.initializeChatSession(
        widget.childData['childId'] ?? "child123",
        widget.childData,
        generativeModel,
      );
      // If an initial response exists, add it to messages.
      if (widget.initialResponse.isNotEmpty) {
        messages.add(ChatMessage(text: widget.initialResponse, isUser: false));
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  // Handle sending user text messages.
  Future<void> _sendMessage(String userMessage) async {
    setState(() {
      isLoading = true;
    });
    try {
      messages.add(ChatMessage(text: userMessage, isUser: true));

      // Optionally, trigger detection (capture frame, etc.) here.
      // Example: String frame = await cameraService.captureFrame();
      // var detectionResult = await detectionController.processFrame(frame);

      final response = await chatController.processUserMessage(userMessage, messages.length);
      messages.add(ChatMessage(text: response, isUser: false));

      // Optionally, speak the response.
      await audioController.speak(response);
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

  // Toggle voice recognition; when user speaks, process the text.
  Future<void> _toggleVoiceRecognition() async {
    await audioController.toggleListening(onResult: (recognizedText) async {
      // Once recognized, send the text as a message.
      if (recognizedText.isNotEmpty) {
        await _sendMessage(recognizedText);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapy Session"),
      ),
      body: Column(
        children: [
          // Display conversation messages.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (isLoading) const CircularProgressIndicator(),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Error: $errorMessage", style: const TextStyle(color: Colors.red)),
            ),
          // Text input and control buttons.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // TextField for manual text input.
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(hintText: "Type your message..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      _sendMessage(text);
                      _textController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          // Button to toggle voice recognition.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _toggleVoiceRecognition,
              icon: Icon(audioController.isListening ? Icons.mic : Icons.mic_none),
              label: Text(audioController.isListening ? "Listening..." : "Start Voice Input"),
            ),
          ),
        ],
      ),
    );
  }
}
