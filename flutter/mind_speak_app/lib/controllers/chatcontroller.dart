// lib/controllers/chat_controller.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mind_speak_app/Repositories/chatrepository.dart';
 
class ChatController {
  final ChatRepository chatRepo;
  ChatSession? chatSession;

  ChatController({required this.chatRepo});

  // Initialize a chat session using child data and the AI model.
  Future<void> initializeChatSession(String childId, Map<String, dynamic> childData, GenerativeModel model) async {
    try {
      chatSession = chatRepo.getOrCreateSession(childId, model, childData);
    } catch (e) {
      throw Exception("Error in ChatController - initializeChatSession: $e");
    }
  }

  // Process a user message and return the AI's response.
  Future<String> processUserMessage(String userMessage, int messageCount) async {
    if (chatSession == null) {
      throw Exception("Chat session not initialized");
    }
    try {
      return await chatRepo.processResponse(chatSession!, userMessage, messageCount);
    } catch (e) {
      throw Exception("Error in ChatController - processUserMessage: $e");
    }
  }

  // End the current chat session.
  void endChatSession(String childId) {
    try {
      chatRepo.endSession(childId);
      chatSession = null;
    } catch (e) {
      throw Exception("Error in ChatController - endChatSession: $e");
    }
  }
}
