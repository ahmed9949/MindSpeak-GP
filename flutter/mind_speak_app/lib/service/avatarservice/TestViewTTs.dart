import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/testGptTts.dart';
 
class GptTtsTestPage extends StatefulWidget {
  const GptTtsTestPage({super.key});

  @override
  State<GptTtsTestPage> createState() => _GptTtsTestPageState();
}

class _GptTtsTestPageState extends State<GptTtsTestPage> {
  final TextEditingController _controller = TextEditingController();
  final ChatGptTtsService _ttsService = ChatGptTtsService();
  bool _isSpeaking = false;

  Future<void> _speakText() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() => _isSpeaking = true);
      await _ttsService.speak(text);
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPT TTS Tester')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('اكتب كلام مصري هنا:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'إزيك؟ عامل إيه النهارده؟',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSpeaking ? null : _speakText,
              icon: const Icon(Icons.volume_up),
              label: const Text('شغل الصوت'),
            ),
          ],
        ),
      ),
    );
  }
}
