import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMService {
  final String apiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  LLMService({required this.apiKey});

  Future<String> getResponse(String text) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: json.encode({
        "model": "mixtral-8x7b-32768",
        "messages": [
          {
            "role": "system",
            "content": """
You are a friendly, patient AI assistant talking with a child.
Keep responses:
- Short and simple (1-2 sentences)
- Encouraging and positive
- Age-appropriate
- Engaging and fun
"""
          },
          {"role": "user", "content": text}
        ],
        "temperature": 0.7,
        "max_tokens": 150,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM API error: ${response.statusCode}');
    }

    final jsonResponse = json.decode(response.body);
    return jsonResponse['choices'][0]['message']['content'] as String;
  }
}