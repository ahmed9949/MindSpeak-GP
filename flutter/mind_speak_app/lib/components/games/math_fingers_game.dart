import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';

class MathFingersGame extends MiniGameBase {
  const MathFingersGame({
    Key? key,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
    required this.level,
  }) : super(key: key);

  final int level;

  @override
  State<MathFingersGame> createState() => _MathFingersGameState();
}

class _MathFingersGameState extends State<MathFingersGame>
    with TickerProviderStateMixin {
  final GameImageService _imageService = GameImageService();

  // Game state
  late int num1;
  late int num2;
  late String operator;
  late int answer;
  late List<int> optionList;

  // Image resources
  String? url1;
  String? url2;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _celebrationController;

  // Value notifiers for state management
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _hasSelectedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showWinAnimationNotifier = ValueNotifier(false);
  final ValueNotifier<int?> _selectedOptionNotifier = ValueNotifier(null);
  final ValueNotifier<bool?> _isCorrectNotifier = ValueNotifier(null);

  bool _didInit = false;
  Completer<void>? _animationCompleter;

  // Preloaded Lottie compositions
  late final Future<LottieComposition> _starsComposition;
  late final Future<LottieComposition> _confettiComposition;

  // Audio resources
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize audio resources
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();

    // Setup audio in parallel
    _setupAudio();

    // Preload Lottie animations
    _starsComposition = AssetLottie('assets/more stars.json').load();
    _confettiComposition = AssetLottie('assets/Confetti.json').load();

    // Generate math problem immediately
    _generateMathProblemNoImages();
  }

  Future<void> _setupAudio() async {
    await Future.wait([
      _correctSound.setSource(AssetSource('audio/correct-answer.wav')),
      _wrongSound.setSource(AssetSource('audio/wrong-answer.wav')),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;

      // Load images with optimized approach
      _loadImages();

      // Clear unused memory to free up resources
      SchedulerBinding.instance.addPostFrameCallback((_) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
    }
  }

  void _generateMathProblemNoImages() {
    final rand = Random();
    num1 = rand.nextInt(6);
    num2 = rand.nextInt(6);

    switch (widget.level) {
      case 5:
        operator = '+';
        answer = num1 + num2;
        break;
      case 6:
        operator = '-';
        // Ensure result is non-negative for subtraction
        if (num1 < num2) {
          final temp = num1;
          num1 = num2;
          num2 = temp;
        }
        answer = num1 - num2;
        break;
      case 7:
        operator = '×';
        answer = num1 * num2;
        break;
      default:
        operator = '+';
        answer = num1 + num2;
    }

    // Create options with more interesting distribution
    Set<int> options = {answer};

    final rand2 = Random();
    while (options.length < 3) {
      // Make options more varied but still reasonable
      int diff = rand2.nextInt(5) - 2;
      // Ensure we don't get duplicates or negative numbers
      final newOption = max(0, answer + diff);
      if (newOption != answer) options.add(newOption);
    }

    optionList = options.toList()..shuffle();
  }

  Future<void> _loadImages() async {
    try {
      // Load images in parallel with optimized retry logic
      final results = await Future.wait([
        _loadFingerImageOptimized(num1),
        _loadFingerImageOptimized(num2),
      ]);

      url1 = results[0];
      url2 = results[1];

      if (url1 == null || url2 == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Failed to load finger images.")),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (mounted) {
        // Precache images for smoother display
        await Future.wait([
          precacheImage(NetworkImage(url1!), context),
          precacheImage(NetworkImage(url2!), context),
        ]);

        // Update loading state
        _isLoadingNotifier.value = false;

        // Speak instruction with frame sync for better timing
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.ttsService.speak("ما ناتج $num1 $operator $num2؟");
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading game: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<String?> _loadFingerImageOptimized(int number) async {
    // More aggressive caching strategy with exponential backoff
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final url = await _imageService.getRandomImage("Fingers", "$number");
        if (url != null) return url;
      } catch (_) {
        // Exponential backoff to avoid hammering the server
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
    }
    // Fallback to a default image or return null
    return null;
  }

  Future<void> _waitForPlayer(AudioPlayer player) async {
    final completer = Completer<void>();

    // More reliable sound completion detection
    void onComplete(PlayerState state) {
      if ((state == PlayerState.completed || state == PlayerState.stopped) &&
          !completer.isCompleted) {
        completer.complete();
      }
    }

    final sub = player.onPlayerStateChanged.listen(onComplete);

    // Shorter timeout for smoother game flow
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await sub.cancel();
  }

  Future<void> _playSound(AudioPlayer player) async {
    // Reset and play for more reliable audio
    await player.stop();
    await Future.delayed(const Duration(milliseconds: 30));
    await player.resume();
    return _waitForPlayer(player);
  }

  void _handleAnswer(int selectedAnswer) async {
    if (_hasSelectedNotifier.value) return;

    // Create a completer to track all animations
    _animationCompleter = Completer<void>();

    // Update notifiers for reactive UI updates
    _hasSelectedNotifier.value = true;
    _selectedOptionNotifier.value = selectedAnswer;
    _isCorrectNotifier.value = selectedAnswer == answer;

    // Run pulse animation
    _pulseController.forward().then((_) => _pulseController.reverse());

    if (selectedAnswer == answer) {
      // Show win animation
      _showWinAnimationNotifier.value = true;
      _celebrationController.forward();

      // Play correct sound
      await _playSound(_correctSound);

      // Speak feedback
      await widget.ttsService.speak("برافو! الإجابة صحيحة");

      // Complete after animations
      Future.delayed(const Duration(milliseconds: 1200), () {
        _animationCompleter?.complete();

        // Signal completion with frame sync
        SchedulerBinding.instance.addPostFrameCallback((_) {
          widget.onCorrect(1);
        });
      });
    } else {
      // Play wrong sound
      await _playSound(_wrongSound);

      // Speak feedback
      await widget.ttsService.speak("لا، حاول مرة أخرى");

      // Reset for next attempt with better timing
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _selectedOptionNotifier.value = null;
          _isCorrectNotifier.value = null;
          _hasSelectedNotifier.value = false;
          widget.onWrong();
        }
      });
    }
  }

  @override
  void dispose() {
    // Clean up all resources properly
    _pulseController.dispose();
    _celebrationController.dispose();
    _correctSound.dispose();
    _wrongSound.dispose();
    _isLoadingNotifier.dispose();
    _hasSelectedNotifier.dispose();
    _showWinAnimationNotifier.dispose();
    _selectedOptionNotifier.dispose();
    _isCorrectNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Loading game..."),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(), // Smoother scrolling
          child: _buildGameContent(context),
        );
      },
    );
  }

  Widget _buildGameContent(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    return RepaintBoundary(
      child: Column(
        children: [
          Text(
            "$num1 $operator $num2 = ?",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _buildFingerImages(),
          const SizedBox(height: 30),
          _buildAnswerOptions(isDark, primaryColor),
          _buildCelebrationAnimation(),
        ],
      ),
    );
  }

  Widget _buildFingerImages() {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First finger image with Hero animation
          Hero(
            tag: 'finger_image_1',
            child: Image.network(
              url1!,
              height: 100,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                return AnimatedOpacity(
                  opacity: frame != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(operator, style: const TextStyle(fontSize: 28)),
          ),
          // Second finger image with Hero animation
          Hero(
            tag: 'finger_image_2',
            child: Image.network(
              url2!,
              height: 100,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                return AnimatedOpacity(
                  opacity: frame != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions(bool isDark, Color primaryColor) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int?>(
        valueListenable: _selectedOptionNotifier,
        builder: (context, selectedOption, _) {
          return ValueListenableBuilder<bool?>(
            valueListenable: _isCorrectNotifier,
            builder: (context, isCorrect, _) {
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: optionList.map((opt) {
                  final isSelected = selectedOption == opt;

                  return AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double scale = 1.0;
                      if (isSelected) {
                        // Smoother pulse animation
                        final pulseValue = _pulseController.value;
                        scale = 1.0 + sin(pulseValue * pi) * 0.1;
                      }
                      return Transform.scale(
                        scale: scale,
                        child: child,
                        filterQuality: FilterQuality.medium,
                      );
                    },
                    child: InkWell(
                      key: ValueKey('option_$opt'),
                      onTap: () => _handleAnswer(opt),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selectedOption == opt
                              ? (isCorrect == true ? Colors.green : Colors.red)
                              : (isDark
                                  ? Colors.grey[800]
                               : primaryColor.withAlpha(229)),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withAlpha(77),

                              offset: const Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          "$opt",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCelebrationAnimation() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showWinAnimationNotifier,
      builder: (context, showWinAnimation, _) {
        return AnimatedOpacity(
          opacity: showWinAnimation ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: showWinAnimation
              ? SmoothCelebration(
                  stars: _starsComposition,
                  confetti: _confettiComposition,
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
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: FutureBuilder(
                future: stars,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return Lottie(
                    composition: snapshot.data!,
                    repeat: false,
                    frameRate:
                        FrameRate(120), // Higher frame rate for smoothness
                    options: LottieOptions(
                      enableMergePaths: true,
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 120,
              child: FutureBuilder(
                future: confetti,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return Lottie(
                    composition: snapshot.data!,
                    repeat: false,
                    frameRate:
                        FrameRate(120), // Higher frame rate for smoothness
                    options: LottieOptions(
                      enableMergePaths: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
