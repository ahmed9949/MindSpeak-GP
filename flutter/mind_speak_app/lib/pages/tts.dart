import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSPage extends StatefulWidget {
  const TTSPage({Key? key}) : super(key: key);

  @override
  State<TTSPage> createState() => _TTSPageState();
}

class _TTSPageState extends State<TTSPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController textController = TextEditingController();
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> speak() async {
    if (textController.text.isNotEmpty) {
      setState(() {
        isSpeaking = true;
      });
      await flutterTts.speak(textController.text);
    }
  }

  Future<void> stop() async {
    setState(() {
      isSpeaking = false;
    });
    await flutterTts.stop();
  }

  @override
  void dispose() {
    flutterTts.stop();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter text to speak',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isSpeaking ? null : speak,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Speak'),
                ),
                ElevatedButton.icon(
                  onPressed: isSpeaking ? stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}