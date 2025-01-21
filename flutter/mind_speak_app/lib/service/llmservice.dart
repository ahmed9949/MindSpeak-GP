import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static final _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;
  late final ChatSession _chat;

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

  Future<String> sendMessageToLLM(
    String userMessage, {
    String systemPrompt = "You are a helpful assistant.",
    int maxTokens = 150,
    double temperature = 0.7,
  }) async {
    try {
      // Create content with system prompt and user message
      final prompt = "$systemPrompt\n\nUser: $userMessage";
      
      final response = await _chat.sendMessage(
        Content.text(prompt),
      );

      if (response.text == null) {
        throw Exception('Empty response from Gemini');
      }

      return response.text!;
    } catch (e) {
      print('Error calling Gemini API: $e');
      throw Exception('Failed to get response from Gemini: $e');
    }
  }

  void clearConversation() {
    _chat = _model.startChat();
  }
}