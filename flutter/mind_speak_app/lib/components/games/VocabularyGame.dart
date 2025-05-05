import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:mind_speak_app/service/avatarservice/static_translation_helper.dart';

class VocabularyGame extends MiniGameBase {
  final String category;
  final int level;
  final int numberOfOptions;

  const VocabularyGame({
    super.key,
    required this.category,
    required this.level,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
    this.numberOfOptions = 4,
  });

  @override
  State<VocabularyGame> createState() => _VocabularyGameState();
}

class _VocabularyGameState extends State<VocabularyGame>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;
  late final AnimationController _shakeController;
  late final StaticTranslationHelper _translationHelper;
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

  // Game state
  late String _targetWord;
  late String _targetTranslation;
  late List<String> _options;
  int _correctIndex = 0;
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
    _translationHelper = StaticTranslationHelper.instance;
    _translationHelper.init();

    // Optimize audio loading - set sources without awaiting
    _loadAudioResources();

    // Preload Lottie animations efficiently
    _starsComposition = AssetLottie('assets/more stars.json').load();
    _confettiComposition = AssetLottie('assets/Confetti.json').load();

    // Initial setup that doesn't require context
    _prepareGameData();
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
    }
  }

  void _prepareGameData() {
    // Get translations for category
    final categoryMap =
        _translationHelper.getCategoryTranslations(widget.category);

    if (categoryMap.isEmpty) {
      // Fallback to Animals category if provided category has no data
      final availableCategories = _translationHelper.getCategories();
      final fallbackCategory = availableCategories.isNotEmpty
          ? availableCategories.first
          : 'Animals';
      final fallbackMap =
          _translationHelper.getCategoryTranslations(fallbackCategory);

      if (fallbackMap.isEmpty) {
        // Critical error - no translations available
        _targetWord = 'Error';
        _targetTranslation = 'خطأ';
        _options = ['خطأ'];
        _correctIndex = 0;
        return;
      }

      _generateGameOptionsFromMap(fallbackMap);
    } else {
      _generateGameOptionsFromMap(categoryMap);
    }
  }

  void _generateGameOptionsFromMap(Map<String, String> categoryMap) {
    // Get a list of all available words
    final availableWords = categoryMap.keys.toList();

    // Randomly select the target word
    final randomIndex = Random().nextInt(availableWords.length);
    _targetWord = availableWords[randomIndex];
    _targetTranslation = categoryMap[_targetWord]!;

    // Generate options with varying difficulty based on level
    _generateOptions(availableWords, categoryMap, widget.level);
  }

  void _generateOptions(
      List<String> availableWords, Map<String, String> categoryMap, int level) {
    // Determine number of options based on level
    final numOptions =
        min(availableWords.length, max(2, widget.numberOfOptions));

    // Start with correct answer
    final List<String> translationOptions = [_targetTranslation];

    // Add other random translations, ensuring no duplicates
    final availableTranslations = categoryMap.values.toList()
      ..remove(_targetTranslation);

    // Shuffle for randomness
    availableTranslations.shuffle();

    // Add random translations until we reach desired number of options
    for (var i = 0;
        i < numOptions - 1 && i < availableTranslations.length;
        i++) {
      translationOptions.add(availableTranslations[i]);
    }

    // Shuffle options
    translationOptions.shuffle();

    // Find the index of the correct answer
    _correctIndex = translationOptions.indexOf(_targetTranslation);
    _options = translationOptions;
  }

  void _finishLoading() {
    // Set loading to false
    _isLoadingNotifier.value = false;

    // Speak instruction after UI is fully rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      widget.ttsService.speak("ما هي الترجمة العربية لكلمة $_targetWord؟");
    });
  }

  Future<void> handleSelection(int index) async {
    if (_hasSelectedNotifier.value) return;

    _hasSelectedNotifier.value = true;

    // Create a completer to track when all animations are finished
    _animationCompleter = Completer<void>();

    if (index != _correctIndex) {
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
                "What is the Arabic translation of \"$_targetWord\"?",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "ما هي الترجمة العربية لكلمة $_targetWord؟",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Arial',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _buildOptionsGrid(),
              const SizedBox(height: 100),
            ],
          ),
        ),
        _buildWinAnimation(),
      ],
    );
  }

  Widget _buildOptionsGrid() {
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
                    spacing: 15,
                    runSpacing: 15,
                    children: List.generate(_options.length, (index) {
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
                              scale: (hasSelected && index == _correctIndex)
                                  ? scale
                                  : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutQuad,
                              child: _buildOptionCard(index, hasSelected),
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

  Widget _buildOptionCard(int index, bool hasSelected) {
    final bool isCorrect = index == _correctIndex;
    final String option = _options[index];

    return GestureDetector(
      key: ValueKey('option_$index'),
      onTap: () => handleSelection(index),
      child: Container(
        width: 150,
        height: 90,
        decoration: BoxDecoration(
          color: hasSelected
              ? (isCorrect
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2))
              : Colors.blue.withOpacity(0.1),
          border: Border.all(
            color: hasSelected
                ? (isCorrect ? Colors.green : Colors.red)
                : Colors.blue,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: hasSelected && isCorrect
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: hasSelected
                    ? (isCorrect ? Colors.green.shade800 : Colors.red.shade800)
                    : Colors.black87,
                fontFamily: 'Arial',
              ),
              textAlign: TextAlign.center,
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
