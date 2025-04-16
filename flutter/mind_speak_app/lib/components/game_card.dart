import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';

class MiniGameCard extends StatefulWidget {
  final String category;
  final String type;
  final int level;
  final Function(int) onCorrect;
  final Function() onWrong;
  final Function() onFinished;
  final ChatGptTtsService ttsService;
  final List<Map<String, dynamic>>? images; // ✅ NEW: cached image support

  const MiniGameCard({
    super.key,
    required this.category,
    required this.type,
    required this.level,
    required this.onCorrect,
    required this.onWrong,
    required this.onFinished,
    required this.ttsService,
    this.images,
  });

  @override
  State<MiniGameCard> createState() => _MiniGameCardState();
}

class _MiniGameCardState extends State<MiniGameCard> {
  final GameImageService _imageService = GameImageService();
  List<String> imageUrls = [];
  int correctIndex = 0;
  bool isLoading = true;
  bool hasSelected = false;

  @override
  void initState() {
    super.initState();

    // ✅ Use cached images if provided
    if (widget.images != null && widget.images!.isNotEmpty) {
      imageUrls = widget.images!.map((img) => img['url'] as String).toList();
      correctIndex = widget.images!.indexWhere((img) => img['isCorrect']);
      isLoading = false;

      final instruction = "فين الـ ${widget.type.toLowerCase()}؟";
      widget.ttsService.speak(instruction);
    } else {
      loadImages();
    }
  }

  Future<void> loadImages() async {
    setState(() => isLoading = true);
    try {
      final images = widget.images ??
          await _imageService.getLabeledImages(
            category: widget.category,
            correctType: widget.type,
            count: widget.level,
          );

      correctIndex = images.indexWhere((img) => img['isCorrect']);
      imageUrls = images.map((img) => img['url'] as String).toList();

      setState(() => isLoading = false);

      // ✅ Speak AFTER images are ready
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

  void handleSelection(int index) {
    setState(() => hasSelected = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (index == correctIndex) {
        widget.onCorrect(1); // ✅ passed
        Navigator.pop(context); // close game
      } else {
        widget.onWrong(); // ❌ retry
        // ⛔ do NOT close sheet
      }
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
                Text(
                  "Where is the ${widget.type.toLowerCase()}?",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(imageUrls.length, (index) {
                    return GestureDetector(
                      onTap: () => handleSelection(index),
                      child: Container(
                        height: 120,
                        width: 120,
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
                const SizedBox(height: 20),
              ],
            ),
          );
  }
}
