//  import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ChatGptModel {
//   final String apiKey;
//   final String model;

//   ChatGptModel({required this.apiKey, this.model = "gpt-3.5-turbo"});

//   /// Sends a prompt to the ChatGPT API and returns the response text.
//   Future<String> sendMessage(String prompt) async {
//     final url = Uri.parse("https://api.openai.com/v1/chat/completions");
//     final headers = {
//       "Content-Type": "application/json",
//       "Authorization": "Bearer $apiKey",
//     };
//     final body = json.encode({
//       "model": model,
//       "messages": [
//         {
//           "role": "system",
//           "content": "You are a helpful therapist assistant."
//         },
//         {"role": "user", "content": prompt}
//       ]
//     });

//     final response = await http.post(url, headers: headers, body: body);
//     if (response.statusCode == 200) {
//       final data = json.decode(utf8.decode(response.bodyBytes));
//       final reply = data["choices"][0]["message"]["content"];
//       return reply;
//     } else {
//       throw Exception("OpenAI API error: ${response.body}");
//     }
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGptModel {
  final String apiKey;
  final String model;
  // Keep track of conversation history
  final List<Map<String, String>> _conversationHistory = [];

  ChatGptModel({required this.apiKey, this.model = "gpt-3.5-turbo"}) {
    // Initialize with system message
    _conversationHistory.add({
      "role": "system",
      "content":
          "You are a helpful therapist assistant for children with autism. Speak in Egyptian Arabic and keep responses supportive, clear, and concise."
    });
  }

  /// Sends a prompt to the ChatGPT API with the entire conversation history
  Future<String> sendMessage(String prompt,
      {Map<String, dynamic>? childData}) async {
    // If childData is provided, add or update the system message with child info
    if (childData != null) {
      final name = childData['name'] ?? '';
      final age = childData['age']?.toString() ?? '';
      final interest = childData['childInterest'] ?? '';

      String systemPrompt = '''
You are a therapist for children with autism, focused on enhancing communication skills.
Talk in Egyptian Arabic.

Child Information:
- Name: $name
- Age: $age
- Main Interest: $interest

Your approach:
1. Start by engaging with their interest in $interest
2. Gradually expand the conversation beyond this interest
3. Keep responses short (2-3 sentences maximum)
4. Use positive reinforcement
5. Be patient and encouraging
6. Always respond in Arabic
''';

      // Replace system message or add it if not present
      if (_conversationHistory.isNotEmpty &&
          _conversationHistory[0]["role"] == "system") {
        _conversationHistory[0] = {"role": "system", "content": systemPrompt};
      } else {
        _conversationHistory
            .insert(0, {"role": "system", "content": systemPrompt});
      }
    }

    // Add user message to history
    _conversationHistory.add({"role": "user", "content": prompt});

    // Ensure conversation doesn't get too long (API limit)
    if (_conversationHistory.length > 20) {
      // Keep system message and last 10 messages
      final systemMessage = _conversationHistory[0];
      _conversationHistory.removeRange(1, _conversationHistory.length - 10);
      _conversationHistory.insert(0, systemMessage);
    }

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    };

    final body = json.encode({
      "model": model,
      "messages": _conversationHistory,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final reply = data["choices"][0]["message"]["content"];

      // Add assistant response to history
      _conversationHistory.add({"role": "assistant", "content": reply});

      return reply;
    } else {
      print("OpenAI API error: ${response.statusCode} - ${response.body}");
      throw Exception("OpenAI API error: ${response.body}");
    }
  }

  // Clear conversation history (useful when starting a new session)
  void clearConversation() {
    _conversationHistory.clear();
    _conversationHistory.add({
      "role": "system",
      "content":
          "You are a helpful therapist assistant for children with autism. Speak in Egyptian Arabic and keep responses supportive, clear, and concise."
    });
  }
}
