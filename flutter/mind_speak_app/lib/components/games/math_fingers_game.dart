import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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

  late int num1;
  late int num2;
  late String operator;
  late int answer;
  late List<int> optionList;

  String? url1;
  String? url2;
  bool isLoading = true;
  bool _didInit = false;
  bool hasSelected = false;

  bool? isCorrect;
  int? selectedOption;
  late AnimationController _pulseController;
  late AnimationController _celebrationController;

  // Preloaded Lottie compositions
  late final Future<LottieComposition> _starsComposition;
  late final Future<LottieComposition> _confettiComposition;

  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;

  bool showWinAnimation = false;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();

    _correctSound.setSource(AssetSource('audio/correct-answer.wav'));
    _wrongSound.setSource(AssetSource('audio/wrong-answer.wav'));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Preload Lottie animations
    _starsComposition = AssetLottie('assets/more stars.json').load();
    _confettiComposition = AssetLottie('assets/Confetti.json').load();

    _generateMathProblemNoImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _loadImages();

      // Clear unused memory
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
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

    Set<int> options = {answer};
    while (options.length < 3) {
      final newOption = answer + rand.nextInt(5) - 2;
      if (newOption >= 0) options.add(newOption);
    }

    optionList = options.toList()..shuffle();
  }

  Future<void> _loadImages() async {
    await Future.wait([
      _loadFingerImage(num1).then((value) => url1 = value),
      _loadFingerImage(num2).then((value) => url2 = value),
    ]);

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
      precacheImage(NetworkImage(url1!), context);
      precacheImage(NetworkImage(url2!), context);

      setState(() => isLoading = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.ttsService.speak("ما ناتج $num1 $operator $num2؟");
      });
    }
  }

  Future<String?> _loadFingerImage(int number) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final url = await _imageService.getRandomImage("Fingers", "$number");
        if (url != null) return url;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return null;
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

  void _handleAnswer(int selectedAnswer) async {
    if (hasSelected) return;

    setState(() {
      hasSelected = true;
      selectedOption = selectedAnswer;
      isCorrect = selectedAnswer == answer;
    });

    _pulseController.forward().then((_) => _pulseController.reverse());

    if (selectedAnswer == answer) {
      // Start celebration animation smoothly
      setState(() => showWinAnimation = true);
      _celebrationController.forward();

      // Stop and play correct sound with delay for smoother transition
      await _correctSound.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _correctSound.play(AssetSource('audio/correct-answer.wav'));

      // Wait for sound to complete
      await _waitForPlayer(_correctSound);

      // Speak feedback
      await widget.ttsService.speak("برافو! الإجابة صحيحة");

      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 1200));

      setState(() => showWinAnimation = false);

      // Trigger next level using frame sync for smoother transition
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCorrect(1);
      });
    } else {
      // Stop and play wrong sound with delay
      await _wrongSound.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _wrongSound.play(AssetSource('audio/wrong-answer.wav'));

      // Wait for sound to complete
      await _waitForPlayer(_wrongSound);

      // Speak feedback
      await widget.ttsService.speak("لا، حاول مرة أخرى");

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          selectedOption = null;
          isCorrect = null;
          hasSelected = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _celebrationController.dispose();
    _correctSound.dispose();
    _wrongSound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      child: RepaintBoundary(
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
            RepaintBoundary(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    url1!,
                    key: const ValueKey('finger_image_1'),
                    height: 100,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      return AnimatedOpacity(
                        opacity: frame != null ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(operator, style: const TextStyle(fontSize: 28)),
                  ),
                  Image.network(
                    url2!,
                    key: const ValueKey('finger_image_2'),
                    height: 100,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      return AnimatedOpacity(
                        opacity: frame != null ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            RepaintBoundary(
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                children: optionList.map((opt) {
                  final isSelected = selectedOption == opt;

                  return AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double scale = 1.0;
                      if (isSelected) {
                        scale = 1.0 + (_pulseController.value * 0.1);
                      }
                      return Transform.scale(scale: scale, child: child);
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
                                  : primaryColor.withOpacity(0.9)),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
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
              ),
            ),
            AnimatedOpacity(
              opacity: showWinAnimation ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: showWinAnimation
                  ? SmoothCelebration(
                      stars: _starsComposition,
                      confetti: _confettiComposition,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
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
                    frameRate: FrameRate.max,
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
                    frameRate: FrameRate.max,
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
