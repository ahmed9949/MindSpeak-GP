// import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ChatService {
//   static final _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';

//   Future<String> sendMessageToLLM(String userMessage) async {
//     if (_groqApiKey.isEmpty) {
//       throw Exception('Groq API key not found in .env file.');
//     }

//     final startTime = DateTime.now();
//     final response = await http.post(
//       Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $_groqApiKey',
//       },
//       body: json.encode({
//         "model": "mixtral-8x7b-32768", // or a smaller/faster model if available
//         "messages": [
//           {
//             "role": "system",
//             "content": "You are a helpful assistant. Provide concise answers."
//           },
//           {"role": "user", "content": userMessage}
//         ],
//         "temperature": 0.7,
//         "max_tokens": 100, // reduce to 100
//       }),
//     );
//     final endTime = DateTime.now();
//     print("LLM request took ${endTime.difference(startTime).inMilliseconds} ms");

//     if (response.statusCode == 200) {
//       final jsonResponse = json.decode(response.body);
//       final llmResponse =
//           jsonResponse['choices'][0]['message']['content'] as String;
//       return llmResponse;
//     } else {
//       throw HttpException(
//         'Groq API error: ${response.statusCode} - ${response.body}',
//       );
//     }
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static final _geminApiKey = dotenv.env['GEMIN_API_KEY'] ?? '';

  Future<String> sendMessageToLLM(String userMessage) async {
    if (_geminApiKey.isEmpty) {
      throw Exception('Gemin AI API key not found in .env file.');
    }

    // Example endpoint for Gemin AI
    final url = 'https://api.gemini.com/v1/chat/completions';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        // Typically 'Authorization': 'Bearer YOUR_KEY', or another header
        'Authorization': 'Bearer $_geminApiKey',
      },
      body: json.encode({
        // Adapt fields to match Gemin AI's prompt schema:
        "model": "gemin-medium-123", // example model name
        "messages": [
          {
            "role": "system",
            "content": "You are a helpful assistant. Provide concise answers."
          },
          {"role": "user", "content": userMessage}
        ],
        "temperature": 0.7,
        "max_tokens": 150,
      }),
    );

    if (response.statusCode == 200) {
      // Adjust parsing to Gemin AI's response structure if different
      final jsonResponse = json.decode(response.body);
      // For a GPT-like structure:
      final llmResponse =
          jsonResponse['choices'][0]['message']['content'] as String;
      return llmResponse;
    } else {
      throw HttpException(
        'Gemin AI error: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
