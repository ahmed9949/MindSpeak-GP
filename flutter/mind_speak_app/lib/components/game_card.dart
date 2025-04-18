import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;

  List<String> imageUrls = [];
  int correctIndex = 0;
  bool isLoading = true;
  bool hasSelected = false;
  bool showWinAnimation = false;
  int? wrongIndex;
  bool shake = false;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();

    if (widget.images != null && widget.images!.isNotEmpty) {
      _loadCachedImages();
    } else {
      _loadImages();
    }
  }

  void _loadCachedImages() {
    imageUrls = widget.images!.map((img) => img['url'] as String).toList();
    correctIndex = widget.images!.indexWhere((img) => img['isCorrect']);
    setState(() => isLoading = false);
    widget.ttsService.speak("فين الـ ${widget.type.toLowerCase()}؟");
  }

  Future<void> _loadImages() async {
    try {
      final images = await _imageService.getLabeledImages(
        category: widget.category,
        correctType: widget.type,
        count: widget.level,
      );
      correctIndex = images.indexWhere((img) => img['isCorrect']);
      imageUrls = images.map((img) => img['url'] as String).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) {
      setState(() => isLoading = false);
      widget.ttsService.speak("فين الـ ${widget.type.toLowerCase()}؟");
    }
  }

  void handleSelection(int index) async {
    if (hasSelected) return;

    setState(() {
      hasSelected = true;
      if (index != correctIndex) {
        wrongIndex = index;
        shake = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 100));

    if (index == correctIndex) {
      setState(() => showWinAnimation = true);

      await Future.wait([
        _correctSound.play(AssetSource('audio/correct-answer.wav')),
        widget.ttsService.speak("برافو! أحسنت"),
      ]);

      await Future.delayed(const Duration(seconds: 1));
      widget.onCorrect(1);
      widget.onFinished();
    } else {
      await Future.wait([
        _wrongSound.play(AssetSource('audio/wrong-answer.wav')),
        widget.ttsService.speak("حاول تاني"),
      ]);

      setState(() {
        shake = false;
        hasSelected = false;
      });

      widget.onWrong();
    }
  }

  @override
  void dispose() {
    _correctSound.dispose();
    _wrongSound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                          end: (shake && index == wrongIndex) ? 1 : 0,
                        ),
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
                              child: CachedNetworkImage(
                                imageUrl: imageUrls[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
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
                    children: const [
                      _LottieWidget(
                          assetPath: 'assets/more stars.json', height: 120),
                      SizedBox(height: 10),
                      _LottieWidget(
                          assetPath: 'assets/Confetti.json', height: 160),
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

class _LottieWidget extends StatelessWidget {
  final String assetPath;
  final double height;

  const _LottieWidget({required this.assetPath, required this.height});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      repeat: false,
    );
  }
}
