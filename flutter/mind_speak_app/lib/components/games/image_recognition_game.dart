import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';

class ImageRecognitionGame extends MiniGameBase {
  final String category;
  final String type;
  final int level;
  final List<Map<String, dynamic>> images;

  const ImageRecognitionGame({
    super.key,
    required this.category,
    required this.type,
    required this.level,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
    required this.images,
  });

  @override
  State<ImageRecognitionGame> createState() => _ImageRecognitionGameState();
}

class _ImageRecognitionGameState extends State<ImageRecognitionGame>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;
  late final AnimationController _shakeController;

  List<String> imageUrls = [];
  int correctIndex = 0;
  bool isLoading = true;
  bool hasSelected = false;
  bool showWinAnimation = false;
  int? wrongIndex;
  bool shake = false;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Preload sounds - these don't need context
    _correctSound.setSource(AssetSource('audio/correct-answer.wav'));
    _wrongSound.setSource(AssetSource('audio/wrong-answer.wav'));

    // Initial load that doesn't use context
    imageUrls = widget.images.map((img) => img['url'] as String).toList();
    correctIndex = widget.images.indexWhere((img) => img['isCorrect'] == true);

    // Log the type for debugging
    print("💡 DEBUG: Image type is '${widget.type}'");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only run once
    if (!_didInit) {
      _didInit = true;
      _finishLoading();
    }
  }

  void _finishLoading() {
    // Pre-cache all images - this uses context so it needs to be after initState
    for (final url in imageUrls) {
      precacheImage(NetworkImage(url), context);
    }

    // Set loading to false
    setState(() => isLoading = false);

    // Speak instruction after UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use the type directly from the widget property
      final typeToAnnounce = widget.type.toLowerCase();
      print("🔊 Announcing: 'فين الـ $typeToAnnounce؟'");
      widget.ttsService.speak("فين الـ $typeToAnnounce؟");
    });
  }

  void handleSelection(int index) async {
    if (hasSelected) return;

    setState(() {
      hasSelected = true;
      if (index != correctIndex) {
        wrongIndex = index;
        shake = true;
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    });

    if (index == correctIndex) {
      setState(() => showWinAnimation = true);

      // 1. Play correct sound
      _correctSound.resume();

      // 2. Speak congratulations message
      await widget.ttsService.speak("برافو! أحسنت");

      // 3. Wait for the animation to complete (1 second)
      await Future.delayed(const Duration(milliseconds: 1000));

      // 4. Only then signal completion to the game manager
      widget.onCorrect(1);
    } else {
      _wrongSound.resume();
      await widget.ttsService.speak("حاول تاني");

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
    _shakeController.dispose();
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
                  RepaintBoundary(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(imageUrls.length, (index) {
                        return AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            double offset = 0.0;
                            if (shake && index == wrongIndex) {
                              offset = sin(_shakeController.value * pi * 4) * 8;
                            }
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              transformHitTests: false,
                              filterQuality: FilterQuality.low,
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            key: ValueKey(
                                'image_option_$index'), // Add keys to options
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
                                  memCacheWidth: 300,
                                  memCacheHeight: 300,
                                  fadeOutDuration:
                                      const Duration(milliseconds: 50),
                                  fadeInDuration:
                                      const Duration(milliseconds: 50),
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            if (showWinAnimation)
              const RepaintBoundary(
                child: Positioned.fill(
                  child: IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LottieWidget(
                            key: ValueKey('stars_animation'),
                            assetPath: 'assets/more stars.json',
                            height: 120),
                        SizedBox(height: 10),
                        _LottieWidget(
                            key: ValueKey('confetti_animation'),
                            assetPath: 'assets/Confetti.json',
                            height: 160),
                      ],
                    ),
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

  const _LottieWidget({
    super.key,
    required this.assetPath,
    required this.height,
  });

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
