import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'dart:math';

class MiniGameCard extends StatefulWidget {
  final String category;
  final String type;
  final Function(int) onCorrect;
  final Function() onFinished;

  const MiniGameCard({
    super.key,
    required this.category,
    required this.type,
    required this.onCorrect,
    required this.onFinished,
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
    loadImages();
  }

  Future<void> loadImages() async {
    setState(() => isLoading = true);

    try {
      final images =
          await _imageService.getTwoRandomImages(widget.category, widget.type);
      correctIndex = Random().nextInt(2);

      setState(() {
        imageUrls = images;
        isLoading = false;
      });
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
        widget.onCorrect(1); // 1 point
      }
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
