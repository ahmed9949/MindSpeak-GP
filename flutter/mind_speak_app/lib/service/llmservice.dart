import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static final _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  Future<String> sendMessageToLLM(String userMessage) async {
    if (_groqApiKey.isEmpty) {
      throw Exception('Groq API key not found in .env file.');
    }

    final startTime = DateTime.now();
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: json.encode({
        "model": "mixtral-8x7b-32768", // or a smaller/faster model if available
        "messages": [
          {
            "role": "system",
            "content": "You are a helpful assistant. Provide concise answers."
          },
          {"role": "user", "content": userMessage}
        ],
        "temperature": 0.7,
        "max_tokens": 100, // reduce to 100
      }),
    );
    final endTime = DateTime.now();
    print("LLM request took ${endTime.difference(startTime).inMilliseconds} ms");

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final llmResponse =
          jsonResponse['choices'][0]['message']['content'] as String;
      return llmResponse;
    } else {
      throw HttpException(
        'Groq API error: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
