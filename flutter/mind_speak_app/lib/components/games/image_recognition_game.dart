import 'dart:async';
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
  double _animationScale = 1.0;

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

      // Clear unused memory after images are loaded
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
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
      // Use staggered animation sequence
      _playStaggeredWinAnimation();

      // Stop previous sounds before playing new ones
      if (_correctSound.state != PlayerState.stopped) {
        await _correctSound.stop();
      }

      // Play correct sound
      await _correctSound.resume();

      // Wait for sound to complete
      await _waitForPlayer(_correctSound);

      // Speak feedback
      await widget.ttsService.speak("برافو! أحسنت");

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1000));

      // Signal completion
      widget.onCorrect(1);
    } else {
      // Stop previous sounds
      if (_wrongSound.state != PlayerState.stopped) {
        await _wrongSound.stop();
      }

      // Play wrong sound
      await _wrongSound.resume();

      // Wait for sound to complete
      await _waitForPlayer(_wrongSound);

      // Speak feedback
      await widget.ttsService.speak("حاول تاني");

      setState(() {
        shake = false;
        hasSelected = false;
      });

      widget.onWrong();
    }
  }

  void _playStaggeredWinAnimation() {
    setState(() => showWinAnimation = true);

    // Additional staggered effects
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _animationScale = 1.2);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _animationScale = 1.0);
    });
  }

  Future<void> _waitForPlayer(AudioPlayer player) async {
    final completer = Completer<void>();

    void onComplete(PlayerState state) {
      if ((state == PlayerState.completed || state == PlayerState.stopped) &&
          !completer.isCompleted) {
        completer.complete();
      }
    }

    final sub = player.onPlayerStateChanged.listen(onComplete);

    // Fallback timeout in case onComplete never fires
    Future.delayed(const Duration(seconds: 2), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await sub.cancel();
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
                          child: AnimatedScale(
                            scale: (hasSelected && index == correctIndex)
                                ? _animationScale
                                : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: GestureDetector(
                              key: ValueKey('image_option_$index'),
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
                                        Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 30, color: Colors.grey),
                                      ),
                                    ),
                                  ),
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
                          key: const ValueKey('stars_animation'),
                          assetPath: 'assets/more stars.json',
                          height: 120,
                        ),
                        const SizedBox(height: 10),
                        _LottieWidget(
                          key: const ValueKey('confetti_animation'),
                          assetPath: 'assets/Confetti.json',
                          height: 160,
                        ),
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
