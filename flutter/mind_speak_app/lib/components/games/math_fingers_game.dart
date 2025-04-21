import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:audioplayers/audioplayers.dart';

class MathFingersGame extends MiniGameBase {
  const MathFingersGame({
    super.key,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
  });

  @override
  State<MathFingersGame> createState() => _MathFingersGameState();
}

class _MathFingersGameState extends State<MathFingersGame>
    with SingleTickerProviderStateMixin {
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

  // For response feedback
  bool? isCorrect;
  int? selectedOption;
  late AnimationController _pulseController;

  // Audio players
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;

  bool showWinAnimation = false;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();

    // Preload sounds - these don't need context
    _correctSound.setSource(AssetSource('audio/correct-answer.wav'));
    _wrongSound.setSource(AssetSource('audio/wrong-answer.wav'));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Generate the problem but don't load images here
    _generateMathProblemNoImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only run once
    if (!_didInit) {
      _didInit = true;
      // Now load images (this uses context)
      _loadImages();
    }
  }

  void _generateMathProblemNoImages() {
    final rand = Random();
    num1 = rand.nextInt(6);
    num2 = rand.nextInt(6);
    operator = ['+', '-', '×'][rand.nextInt(3)];

    switch (operator) {
      case '+':
        answer = num1 + num2;
        break;
      case '-':
        answer = num1 - num2;
        break;
      case '×':
        answer = num1 * num2;
        break;
      default:
        answer = 0;
    }

    Set<int> options = {answer};
    while (options.length < 3) {
      // Generate answers close to the correct one but avoid negatives
      final newOption = answer + rand.nextInt(5) - 2;
      if (newOption >= 0) options.add(newOption);
    }
    optionList = options.toList()..shuffle();
  }

  Future<void> _loadImages() async {
    // Load finger images (try to use cached versions if available)
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
      // Precache images for better performance
      precacheImage(NetworkImage(url1!), context);
      precacheImage(NetworkImage(url2!), context);

      setState(() => isLoading = false);

      // Speak after UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.ttsService.speak("ما ناتج $num1 $operator $num2؟");
      });
    }
  }

  Future<String?> _loadFingerImage(int number) async {
    // Try to get image URL (with retry mechanism)
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final url = await _imageService.getRandomImage("Fingers", "$number");
        if (url != null) return url;
      } catch (e) {
        // Wait a moment before retrying
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return null;
  }

  // Update the _handleAnswer method in MathFingersGame to wait for speech before proceeding

  void _handleAnswer(int selectedAnswer) async {
    setState(() {
      selectedOption = selectedAnswer;
      isCorrect = selectedAnswer == answer;
    });

    _pulseController.forward().then((_) => _pulseController.reverse());

    if (selectedAnswer == answer) {
      setState(() => showWinAnimation = true);

      // 1. Play correct sound
      await _correctSound.stop();
      await _correctSound.play(AssetSource('audio/correct-answer.wav'));

      // 2. Speak congratulations after sound
      await widget.ttsService.speak("برافو! الإجابة صحيحة");

      // 3. Wait a moment for animation to complete
      await Future.delayed(const Duration(milliseconds: 1200));

      setState(() => showWinAnimation = false);

      // 4. Trigger next level
      widget.onCorrect(1);
    } else {
      await _wrongSound.stop();
      await _wrongSound.play(AssetSource('audio/wrong-answer.wav'));
      await widget.ttsService.speak("لا، حاول مرة أخرى");

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          selectedOption = null;
          isCorrect = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
            Row(
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
                        // Pulse animation when selected
                        scale = 1.0 + (_pulseController.value * 0.1);
                      }

                      return Transform.scale(
                        scale: scale,
                        child: child,
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
            if (showWinAnimation)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      child:
                          Lottie.asset('assets/more stars.json', repeat: false),
                    ),
                    SizedBox(
                      height: 120,
                      child:
                          Lottie.asset('assets/Confetti.json', repeat: false),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
