

 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatGptModel {
  final String apiKey;
  final String model;

  ChatGptModel({required this.apiKey, this.model = "gpt-3.5-turbo"});

  /// Sends a prompt to the ChatGPT API and returns the response text.
  Future<String> sendMessage(String prompt) async {
    final url = Uri.parse("https://api.openai.com/v1/chat/completions");
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    };
    final body = json.encode({
      "model": model,
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful therapist assistant."
        },
        {"role": "user", "content": prompt}
      ]
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final reply = data["choices"][0]["message"]["content"];
      return reply;
    } else {
      throw Exception("OpenAI API error: ${response.body}");
    }
  }
}
