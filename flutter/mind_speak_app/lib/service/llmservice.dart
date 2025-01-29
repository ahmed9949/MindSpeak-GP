import 'dart:math';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static final _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final List<String> assessmentQuestions = [
    "How old are you?",
    "Can you repeat after me: 'I am a big boy/girl and I love playing with my friends'",
    "What do you use for eating?",
    "What do you use for drinking?",
    "What do you use for reading?",
    "Can you name 3 animals that have 4 legs?",
    "What is a car?",
    "Would you like to tell me a short story?",
    "What do you do if you get lost?",
    "Where do people go when they are sick?",
    "Why do we clean our teeth?",
    "Why do we wash our face?",
    "Can you tell me the days of the week?",
  ];
  final Set<int> _askedQuestions = {};

  ChatService() {
    if (_geminiApiKey.isEmpty) {
      throw Exception('Gemini API key not found in .env file.');
    }

    // Initialize the model
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: _geminiApiKey,
    );

    // Start a new chat session
    _chat = _model.startChat();
  }

  String? getRandomQuestion() {
    if (_askedQuestions.length >= assessmentQuestions.length) {
      return null; // All questions have been asked
    }

    Random random = Random();
    int questionIndex;
    do {
      questionIndex = random.nextInt(assessmentQuestions.length);
    } while (_askedQuestions.contains(questionIndex));

    _askedQuestions.add(questionIndex);
    return assessmentQuestions[questionIndex];
  }

  Future<String> sendMessageToLLM(
    String userMessage, {
    String systemPrompt = "You are a helpful assistant.",
    int maxTokens = 150,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _chat.sendMessage(Content.text(userMessage));

      // Skip random questions for the initial welcome message
      if (userMessage.startsWith("Welcome")) {
        return response.text ?? "Welcome message could not be delivered.";
      }

      // Original logic for random assessment questions
      if (Random().nextDouble() < 0.2) {
        final question = getRandomQuestion();
        if (question != null) {
          return "${response.text}\n\nI'd like to ask you something: $question";
        }
      }

      return response.text ?? "I'm not sure how to respond to that.";
    } catch (e) {
      print('Error calling Gemini API: $e');
      throw Exception('Failed to get response from Gemini: $e');
    }
  }

  void clearConversation() {
    _chat = _model.startChat();
  }
}
