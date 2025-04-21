import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';

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

  bool? isCorrect;
  int? selectedOption;
  late AnimationController _pulseController;

  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;

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

    _generateMathProblemNoImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _loadImages();
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

  void _handleAnswer(int selectedAnswer) async {
    setState(() {
      selectedOption = selectedAnswer;
      isCorrect = selectedAnswer == answer;
    });

    _pulseController.forward().then((_) => _pulseController.reverse());

    if (selectedAnswer == answer) {
      _correctSound.resume();
      await widget.ttsService.speak("برافو! الإجابة صحيحة");
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      final overlay = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: Material(
            color: Colors.black.withOpacity(0.6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/level up.json', height: 200),
                const SizedBox(height: 10),
                const Text(
                  "Level Up!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      final player = AudioPlayer();
      await Future.wait([
        player.play(AssetSource('audio/completion-of-level.wav')),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
      overlayEntry.remove();

      widget.onCorrect(1); // ⬆️ Tell parent to increment level
    } else {
      _wrongSound.resume();
      await widget.ttsService.speak("لا، حاول مرة أخرى");

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          selectedOption = null;
          isCorrect = null;
        });
      }

      widget.onWrong();
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
              Image.network(url1!, height: 100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(operator, style: const TextStyle(fontSize: 28)),
              ),
              Image.network(url2!, height: 100),
            ],
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: optionList.map((opt) {
              final isSelected = selectedOption == opt;

              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = isSelected ? 1.0 + (_pulseController.value * 0.1) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: InkWell(
                  onTap: () => _handleAnswer(opt),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
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
        ],
      ),
    );
  }
}
