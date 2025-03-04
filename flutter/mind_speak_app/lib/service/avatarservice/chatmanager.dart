 
import 'package:google_generative_ai/google_generative_ai.dart';
  
class ChatManager {
  static final Map<String, ChatSession> _chatSessions = {};
  
  static ChatSession getOrCreateSession(String childId, GenerativeModel model, Map<String, dynamic> childData) {
    if (!_chatSessions.containsKey(childId)) {
      final session = model.startChat(history: [
        Content.text('''
You are a specialized therapist for children with autism. Your current patient is:

CHILD INFORMATION:
- Name: ${childData['name']}
- Age: ${childData['age']}
- Primary Interest: ${childData['childInterest']}

THERAPEUTIC OBJECTIVES:
1. Start with their interest in ${childData['childInterest']} to build rapport
2. Gradually introduce related topics to expand conversation
3. Practice turn-taking in conversation
4. Encourage descriptive language
5. Build social communication skills

CONVERSATION STRATEGY:
1. First 3-4 exchanges: Focus on their interest (${childData['childInterest']})
2. Next 3-4 exchanges: Connect their interest to related topics
3. Final exchanges: Introduce new but related subjects

RESPONSE RULES:
1. Keep responses to 2 sentences maximum
2. Use clear, egyptian  Arabic
3. Ask open-ended questions
4. Acknowledge their responses positively
5. Model proper social communication

TOPIC PROGRESSION EXAMPLE:
${childData['childInterest']} → Related activities → Daily experiences → Feelings and opinions

Remember: Your goal is to maintain engagement while gradually expanding the conversation scope.
''')
      ]);
      _chatSessions[childId] = session;
    }
    return _chatSessions[childId]!;
  }

  static Future<String> processResponse(ChatSession session, String userMessage, int messageCount) async {
    String promptContext = '''
Current message number: $messageCount
Child's message: $userMessage

Based on the message count and therapeutic objectives:
${messageCount <= 4 ? "Focus on their primary interest and build rapport" :
  messageCount <= 8 ? "Start connecting their interest to related topics" :
  "Introduce new but related topics while maintaining engagement"}

Respond in 2 sentences maximum, focusing on:
1. Acknowledging their input
2. Asking an engaging follow-up question
3. Encouraging deeper conversation
''';

    final response = await session.sendMessage(Content.text(promptContext));
    return response.text ?? "عذراً، لم أستطع توليد رد.";
  }

  static void endSession(String childId) {
    _chatSessions.remove(childId);
  }
}

