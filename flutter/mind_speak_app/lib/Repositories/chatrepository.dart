// lib/repositories/chat_repository.dart

import 'package:google_generative_ai/google_generative_ai.dart';
 import 'package:mind_speak_app/service/avatarservice/chatmanager.dart'; // Ensure this path matches your project structure

class ChatRepository {
  // Retrieve or create a chat session using the ChatManager.
  ChatSession getOrCreateSession(String childId, GenerativeModel model, Map<String, dynamic> childData) {
    try {
      return ChatManager.getOrCreateSession(childId, model, childData);
    } catch (e) {
      throw Exception("Error creating chat session: $e");
    }
  }

  // Process the user message and return the AI's response.
  Future<String> processResponse(ChatSession session, String userMessage, int messageCount) async {
    try {
      return await ChatManager.processResponse(session, userMessage, messageCount);
    } catch (e) {
      throw Exception("Error processing chat response: $e");
    }
  }

  // End the chat session.
  void endSession(String childId) {
    try {
      ChatManager.endSession(childId);
    } catch (e) {
      throw Exception("Error ending chat session: $e");
    }
  }
}
