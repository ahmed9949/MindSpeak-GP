import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:audioplayers/audioplayers.dart';

class MiniGameCard extends StatefulWidget {
  final String category;
  final String type;
  final int level;
  final Function(int) onCorrect;
  final Function() onWrong;
  final Function() onFinished;
  final ChatGptTtsService ttsService;
  final List<Map<String, dynamic>>? images;

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
  bool showWinAnimation = false;
  int? wrongIndex;
  bool shake = false;
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    if (widget.images != null && widget.images!.isNotEmpty) {
      imageUrls = widget.images!.map((img) => img['url'] as String).toList();
      correctIndex = widget.images!.indexWhere((img) => img['isCorrect']);
      isLoading = false;
      widget.ttsService.speak("فين الـ ${widget.type.toLowerCase()}؟");
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

      await widget.ttsService.speak("فين الـ ${widget.type.toLowerCase()}؟");
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

  // MiniGameCard.dart
  void handleSelection(int index) async {
    if (hasSelected) return;

    setState(() {
      hasSelected = true;
      if (index != correctIndex) {
        wrongIndex = index;
        shake = true;
      }
    });

    // 🔥 Removed delay or kept it very small for smoother effect
    await Future.delayed(const Duration(milliseconds: 100));

    if (index == correctIndex) {
      await _player.play(AssetSource('audio/correct-answer.wav'));
      setState(() => showWinAnimation = true); // 🎉 Trigger immediately
      await widget.ttsService.speak("برافو! أحسنت");

      await Future.delayed(const Duration(seconds: 2)); // Show confetti

      widget.onCorrect(1);
      widget.onFinished();

      if (context.mounted) Navigator.pop(context);
    } else {
      await _player.play(AssetSource('audio/wrong-answer.wav'));
      await widget.ttsService.speak("حاول تاني");

      setState(() {
        shake = false;
        hasSelected = false;
      });
      widget.onWrong();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Where is the ${widget.type.toLowerCase()}?",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(imageUrls.length, (index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0,
                            end: (shake && index == wrongIndex) ? 1 : 0),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, value, child) {
                          final offset = sin(value * pi * 4) * 10;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: () => handleSelection(index),
                          child: Container(
                            height: 150,
                            width: 150,
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
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            if (showWinAnimation)
              Positioned.fill(
                child: IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('assets/more stars.json',
                          height: 120, repeat: false),
                      const SizedBox(height: 10),
                      Lottie.asset('assets/Confetti.json',
                          height: 160, repeat: false),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
