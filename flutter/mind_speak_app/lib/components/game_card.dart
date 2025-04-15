import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';

class MiniGameCard extends StatefulWidget {
  final String category;
  final String type;
  final Function(int) onCorrect;
  final Function() onFinished;
  final ChatGptTtsService ttsService;
  final Future<void> Function()? onImagesLoaded;

  const MiniGameCard({
    super.key,
    required this.category,
    required this.type,
    required this.onCorrect,
    required this.onFinished,
    required this.ttsService,
    this.onImagesLoaded,
  });

  @override
  State<MiniGameCard> createState() => _MiniGameCardState();
}

class _MiniGameCardState extends State<MiniGameCard> {
  final GameImageService _imageService = GameImageService();
  final ChatGptTtsService _ttsService = ChatGptTtsService();

  List<String> imageUrls = [];
  int correctIndex = 0;
  bool isLoading = true;
  bool hasSelected = false;

  @override
  void initState() {
    super.initState();
    loadImages();
  }

  Future<void> loadImages() async {
    setState(() => isLoading = true);
    try {
      final images =
          await _imageService.getTwoLabeledImages(widget.category, widget.type);

      correctIndex = images.indexWhere((img) => img['isCorrect']);
      imageUrls = images.map((img) => img['url'] as String).toList();

      setState(() => isLoading = false);

      // ✅ Only speak now, AFTER images are loaded
      final instruction = "فين الـ ${widget.type.toLowerCase()}؟";
      await widget.ttsService.speak(instruction);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void handleSelection(int index) async {
    setState(() => hasSelected = true);

    if (index == correctIndex) {
      await _ttsService.speak("شاطر جدًا، إجابة صحيحة!");
      widget.onCorrect(1);
    } else {
      await _ttsService.speak("قربت! المرة الجاية هتعرفها");
    }

    Future.delayed(const Duration(seconds: 1), () {
      widget.onFinished();
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Mini Game",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text("Where is the ${widget.type.toLowerCase()}?"),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(2, (index) {
                    return GestureDetector(
                      onTap: () => handleSelection(index),
                      child: Container(
                        height: 140,
                        width: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: hasSelected
                                ? (index == correctIndex
                                    ? Colors.green
                                    : Colors.red)
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
  }
}
