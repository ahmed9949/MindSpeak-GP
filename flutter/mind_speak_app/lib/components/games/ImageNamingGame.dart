import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/static_translation_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ImageNamingGame extends MiniGameBase {
  final int level;
  final String? category;

  const ImageNamingGame({
    super.key,
    required this.level,
    this.category,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
  });

  @override
  State<ImageNamingGame> createState() => _ImageNamingGameState();
}

class _ImageNamingGameState extends State<ImageNamingGame>
    with SingleTickerProviderStateMixin {
  final GameImageService _imageService = GameImageService();
  late final StaticTranslationHelper _translationHelper;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedWord = '';

  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;
  late final AudioPlayer _timerSound;

  Timer? _gameTimer;
  final ValueNotifier<int> _timeLeftNotifier = ValueNotifier(30);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _showWinAnimationNotifier = ValueNotifier(false);

  String _imageUrl = '';
  String _correctType = '';
  String _arabicType = '';

  late final int _maxTime;
  late final bool _useTimer;

  Future<LottieComposition?>? _starsComposition;
  Future<LottieComposition?>? _confettiComposition;
  Completer<void>? _animationCompleter;

  @override
  void initState() {
    super.initState();
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();
    _timerSound = AudioPlayer();
    _translationHelper = StaticTranslationHelper.instance;
    _translationHelper.init();

    _maxTime = max(10, 40 - (widget.level * 3));
    _useTimer = widget.level >= 5;
    _timeLeftNotifier.value = _maxTime;

    _loadAudioResources();
    _starsComposition =
        AssetLottie('assets/more stars.json').load().catchError((e) => null);
    _confettiComposition =
        AssetLottie('assets/Confetti.json').load().catchError((e) => null);
  }

  Future<void> _loadAudioResources() async {
    await Future.wait([
      _correctSound
          .setSource(AssetSource('audio/correct-answer.wav'))
          .catchError((e) => null),
      _wrongSound
          .setSource(AssetSource('audio/wrong-answer.wav'))
          .catchError((e) => null),
      _timerSound
          .setSource(AssetSource('audio/wrong-answer.wav'))
          .catchError((e) => null),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    try {
      final categories = widget.category != null
          ? [widget.category!]
          : _translationHelper.getCategories();
      final selectedCategory = categories[Random().nextInt(categories.length)];
      final categoryMap =
          _translationHelper.getCategoryTranslations(selectedCategory);
      final entries = categoryMap.entries.toList();
      final randomEntry = entries[Random().nextInt(entries.length)];
      _correctType = randomEntry.key;
      _arabicType = randomEntry.value;

      final images = await _imageService.getLabeledImages(
        category: selectedCategory,
        correctType: _correctType,
        count: 1,
      );

      if (images.isEmpty) throw Exception("No images found for selected type");

      _imageUrl = images.first['url'] as String? ?? '';
      if (_imageUrl.isEmpty) throw Exception("Invalid image URL");

      _isLoadingNotifier.value = false;
      if (_useTimer) _startTimer();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        widget.ttsService.speak("ما هذا؟");
      });
    } catch (e) {
      print("Error loading game data: $e");
      _isLoadingNotifier.value = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
      Future.delayed(const Duration(seconds: 2), () => widget.onWrong());
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftNotifier.value <= 0) {
        _gameTimer?.cancel();
        widget.ttsService.speak("انتهى الوقت");
        Future.delayed(const Duration(seconds: 1), () => widget.onWrong());
      } else {
        if (_timeLeftNotifier.value <= 5)
          _timerSound.resume().catchError((e) => null);
        _timeLeftNotifier.value -= 1;
      }
    });
  }

  Future<void> _startVoiceRecognition() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        _isListening = true;
        _speech.listen(
          onResult: (result) async {
            if (result.finalResult) {
              _recognizedWord = result.recognizedWords.trim().toLowerCase();
              _speech.stop();
              _isListening = false;
              await _handleVoiceInput(_recognizedWord);
            }
          },
          localeId: 'ar-EG',
        );
      } else {
        print("Speech recognition not available");
      }
    } else {
      _speech.stop();
      _isListening = false;
    }
  }

  Future<void> _handleVoiceInput(String spokenWord) async {
    _gameTimer?.cancel();
    final isCorrect =
        _translationHelper.isCorrectAnswer(spokenWord, _correctType);

    if (isCorrect) {
      _showWinAnimationNotifier.value = true;
      await _playSound(_correctSound);
      await widget.ttsService.speak("برافو! أحسنت");
      await Future.delayed(const Duration(seconds: 1));
      widget.onCorrect(1);
    } else {
      await _playSound(_wrongSound);
      await widget.ttsService.speak("حاول تاني");
      if (_useTimer) {
        _timeLeftNotifier.value = _maxTime;
        _startTimer();
      }
      widget.onWrong();
    }
  }

  Future<void> _playSound(AudioPlayer player) async {
    await player.stop().catchError((e) => null);
    await Future.delayed(const Duration(milliseconds: 30));
    await player.resume().catchError((e) => null);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _correctSound.dispose();
    _wrongSound.dispose();
    _timerSound.dispose();
    _isLoadingNotifier.dispose();
    _timeLeftNotifier.dispose();
    _showWinAnimationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) return const Center(child: CircularProgressIndicator());
        return SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimer(),
              const SizedBox(height: 10),
              Text("ما هذا؟",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildImageCard(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startVoiceRecognition,
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                label: Text(_isListening ? "جاري الاستماع..." : "اضغط للتحدث"),
              ),
              // Fixed win animation with constraints
              _buildWinAnimation(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimer() {
    if (!_useTimer) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: _timeLeftNotifier,
      builder: (context, timeLeft, _) {
        final color = timeLeft <= 5
            ? Colors.red
            : (timeLeft <= 10 ? Colors.orange : Colors.green);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, color: color),
            const SizedBox(width: 8),
            Text("$timeLeft s",
                style: TextStyle(
                    fontSize: 18, color: color, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  Widget _buildImageCard() {
    return Container(
      height: 220,
      width: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: _imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) =>
              const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }

  Widget _buildWinAnimation() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showWinAnimationNotifier,
      builder: (context, showWin, _) {
        if (!showWin) return const SizedBox.shrink();

        // Fixed animation with specific constraints and clipping
        return SizedBox(
          // Set a fixed height that's 22px less to account for overflow
          height: 128, // 150 - 22 = 128
          // Use ClipRect to ensure animation doesn't overflow
          child: ClipRect(
            child: Lottie.asset(
              'assets/more stars.json',
              repeat: false,
              // Use fit to ensure animation stays within bounds
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
