import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  late final ValueNotifier<double> _animationScaleNotifier;

  // Cached Lottie compositions
  late final Future<LottieComposition> _starsComposition;
  late final Future<LottieComposition> _confettiComposition;

  // Using ValueNotifiers to minimize rebuilds
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _hasSelectedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showWinAnimationNotifier = ValueNotifier(false);
  final ValueNotifier<int?> _wrongIndexNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _shakeNotifier = ValueNotifier(false);

  List<String> imageUrls = [];
  int correctIndex = 0;
  bool _didInit = false;
  Completer<void>? _animationCompleter;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationScaleNotifier = ValueNotifier(1.0);

    // Optimize audio loading - set sources without awaiting
    _loadAudioResources();

    // Preload Lottie animations efficiently
    _starsComposition = AssetLottie('assets/more stars.json').load();
    _confettiComposition = AssetLottie('assets/Confetti.json').load();

    // Initial load that doesn't use context
    imageUrls = widget.images.map((img) => img['url'] as String).toList();
    correctIndex = widget.images.indexWhere((img) => img['isCorrect'] == true);
  }

  Future<void> _loadAudioResources() async {
    // Load audio in parallel rather than sequentially
    await Future.wait([
      _correctSound.setSource(AssetSource('audio/correct-answer.wav')),
      _wrongSound.setSource(AssetSource('audio/wrong-answer.wav')),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only run once
    if (!_didInit) {
      _didInit = true;
      _finishLoading();

      // Clear unused memory after images are loaded
      SchedulerBinding.instance.addPostFrameCallback((_) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
    }
  }

  void _finishLoading() {
    // Pre-cache all images efficiently using computed memory settings
    for (final url in imageUrls) {
      precacheImage(NetworkImage(url), context);
    }

    // Set loading to false
    _isLoadingNotifier.value = false;

    // Speak instruction after UI is fully rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final typeToAnnounce = widget.type.toLowerCase();
      widget.ttsService.speak("فين الـ $typeToAnnounce؟");
    });
  }

  Future<void> handleSelection(int index) async {
    if (_hasSelectedNotifier.value) return;

    _hasSelectedNotifier.value = true;

    // Create a completer to track when all animations are finished
    _animationCompleter = Completer<void>();

    if (index != correctIndex) {
      _wrongIndexNotifier.value = index;
      _shakeNotifier.value = true;
      _shakeController.forward().then((_) => _shakeController.reset());

      // Play wrong sound efficiently
      await _playSound(_wrongSound);

      // Speak feedback
      await widget.ttsService.speak("حاول تاني");

      _wrongIndexNotifier.value = null;
      _shakeNotifier.value = false;
      _hasSelectedNotifier.value = false;

      widget.onWrong();
    } else {
      // Use efficient win animation sequence
      _playWinAnimationSequence();

      // Play correct sound
      await _playSound(_correctSound);

      // Speak feedback
      await widget.ttsService.speak("برافو! أحسنت");

      // Wait for animation to complete
      await _animationCompleter?.future;

      // Signal completion after animations are done
      widget.onCorrect(1);
    }
  }

  Future<void> _playSound(AudioPlayer player) async {
    // Stop and reset before playing to avoid audio glitches
    await player.stop();
    await Future.delayed(const Duration(milliseconds: 30));
    await player.resume();

    // Wait for sound to complete
    return _waitForPlayer(player);
  }

  void _playWinAnimationSequence() {
    // Show win animation with smooth scaling
    _showWinAnimationNotifier.value = true;

    // Use ticker for smoother animation timing
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _animationScaleNotifier.value = 1.15;

      SchedulerBinding.instance.scheduleFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _animationScaleNotifier.value = 1.0;

          // Complete animation after a delay
          Future.delayed(const Duration(milliseconds: 1000), () {
            _animationCompleter?.complete();
          });
        });
      });
    });
  }

  Future<void> _waitForPlayer(AudioPlayer player) async {
    final completer = Completer<void>();

    // Use subscription for reliable completion detection
    final sub = player.onPlayerStateChanged.listen((state) {
      if ((state == PlayerState.completed || state == PlayerState.stopped) &&
          !completer.isCompleted) {
        completer.complete();
      }
    });

    // Fallback timeout in case onComplete never fires
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await sub.cancel();
  }

  @override
  void dispose() {
    // Clean up all resources
    _correctSound.dispose();
    _wrongSound.dispose();
    _shakeController.dispose();
    _isLoadingNotifier.dispose();
    _hasSelectedNotifier.dispose();
    _showWinAnimationNotifier.dispose();
    _wrongIndexNotifier.dispose();
    _shakeNotifier.dispose();
    _animationScaleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use ValueListenableBuilder to minimize rebuilds
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), // Smoother scrolling
            child: _buildGameContent(),
          ),
        );
      },
    );
  }

  Widget _buildGameContent() {
    return Stack(
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
              _buildImageGrid(),
              const SizedBox(height: 100),
            ],
          ),
        ),
        _buildWinAnimation(),
      ],
    );
  }

  Widget _buildImageGrid() {
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _hasSelectedNotifier,
        builder: (context, hasSelected, _) {
          return ValueListenableBuilder<int?>(
            valueListenable: _wrongIndexNotifier,
            builder: (context, wrongIndex, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _shakeNotifier,
                builder: (context, shake, _) {
                  return Wrap(
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
                        child: ValueListenableBuilder<double>(
                          valueListenable: _animationScaleNotifier,
                          builder: (context, scale, _) {
                            return AnimatedScale(
                              scale: (hasSelected && index == correctIndex)
                                  ? scale
                                  : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutQuad,
                              child: _buildImageCard(index, hasSelected),
                            );
                          },
                        ),
                      );
                    }),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildImageCard(int index, bool hasSelected) {
    return GestureDetector(
      key: ValueKey('image_option_$index'),
      onTap: () => handleSelection(index),
      child: Container(
        height: 150,
        width: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: hasSelected
                ? (index == correctIndex ? Colors.green : Colors.red)
                : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasSelected && index == correctIndex
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Hero(
            tag: 'image_$index',
            child: CachedNetworkImage(
              imageUrl: imageUrls[index],
              fit: BoxFit.cover,
              memCacheWidth: 300,
              memCacheHeight: 300,
              fadeOutDuration: const Duration(milliseconds: 50),
              fadeInDuration: const Duration(milliseconds: 50),
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinAnimation() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showWinAnimationNotifier,
      builder: (context, showWinAnimation, _) {
        return AnimatedOpacity(
          opacity: showWinAnimation ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: showWinAnimation
              ? RepaintBoundary(
                  child: SmoothCelebration(
                    stars: _starsComposition,
                    confetti: _confettiComposition,
                  ),
                )
              : const SizedBox(),
        );
      },
    );
  }
}

class SmoothCelebration extends StatelessWidget {
  final Future<LottieComposition> stars;
  final Future<LottieComposition> confetti;

  const SmoothCelebration({
    super.key,
    required this.stars,
    required this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FutureBuilder<LottieComposition>(
            future: stars,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Lottie(
                composition: snapshot.data!,
                repeat: false,
                height: 120,
                frameRate: FrameRate(120), // Increase frame rate for smoothness
                options: LottieOptions(
                  enableMergePaths: true,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          FutureBuilder<LottieComposition>(
            future: confetti,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Lottie(
                composition: snapshot.data!,
                repeat: false,
                height: 160,
                frameRate: FrameRate(120), // Increase frame rate for smoothness
                options: LottieOptions(
                  enableMergePaths: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
