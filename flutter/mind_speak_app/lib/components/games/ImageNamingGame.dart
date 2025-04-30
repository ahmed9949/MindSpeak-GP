import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mind_speak_app/service/avatarservice/static_translation_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';

class ImageNamingGame extends MiniGameBase {
  final int level;

  const ImageNamingGame({
    super.key,
    required this.level,
    required super.ttsService,
    required super.onCorrect,
    required super.onWrong,
  });

  @override
  State<ImageNamingGame> createState() => _ImageNamingGameState();
}

class _ImageNamingGameState extends State<ImageNamingGame>
    with SingleTickerProviderStateMixin {
  // Services
  final GameImageService _imageService = GameImageService();
  final StaticTranslationHelper _translationHelper =
      StaticTranslationHelper.instance;
  late final stt.SpeechToText _speech;

  // Game state with value notifiers for reactive updates
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isListeningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showWinAnimationNotifier = ValueNotifier(false);
  final ValueNotifier<String?> _currentWordNotifier = ValueNotifier(null);
  final ValueNotifier<bool?> _isCorrectNotifier = ValueNotifier(null);
  final ValueNotifier<double> _confidenceNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _animationScaleNotifier = ValueNotifier(1.0);

  // Image resources (marked late for memory efficiency)
  late String _imageUrl;
  late String _correctType;
  late String _category;
  String? _arabicName;

  // Audio resources (pre-initialized to reduce delays)
  late final AudioPlayer _correctSound;
  late final AudioPlayer _wrongSound;
  late final AudioPlayer _listeningSound;

  // Cached Lottie compositions for better performance
  late final Future<LottieComposition> _starsComposition;
  late final Future<LottieComposition> _confettiComposition;
  late final Future<LottieComposition> _listeningComposition;

  // Game state
  bool _didInit = false;
  Completer<void>? _animationCompleter;
  bool _hasGuessed = false;

  // Animation controller for pulse effect
  late AnimationController _pulseController;

  // Locale for speech recognition
  String? _speechLocale;

  // Common categories and predefined level settings
  static const List<String> _basicCategories = [
    'Animals',
    'Fruits',
    'Body_Parts'
  ];
  static const List<String> _advancedCategories = [
    'Vehicles',
    'Household_Items'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize translation helper
    _translationHelper.init();

    // Initialize speech recognition
    _speech = stt.SpeechToText();

    // Initialize animation controller with optimized settings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Initialize audio players (eager initialization)
    _correctSound = AudioPlayer();
    _wrongSound = AudioPlayer();
    _listeningSound = AudioPlayer();

    // Pre-load Lottie animations with optimized caching
    _starsComposition = AssetLottie('assets/more stars.json').load();
    _confettiComposition = AssetLottie('assets/Confetti.json').load();
    _listeningComposition =
        AssetLottie('assets/listening_animation.json').load();

    // Initialize speech and audio in parallel for faster startup
    _initializeConcurrently();
  }

  // Run initialization tasks concurrently for better performance
  Future<void> _initializeConcurrently() async {
    await Future.wait([
      _initSpeech(),
      _loadAudioResources(),
    ]);
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) => print('Speech recognition error: $error'),
      );

      // Pre-fetch the best locale for better startup performance later
      if (_speech.isAvailable) {
        final locales = await _speech.locales();
        _speechLocale = _findBestLocale(locales);
      }
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
    }
  }

  // Find the best locale for Arabic speech recognition
  String _findBestLocale(List<stt.LocaleName> locales) {
    // Preferred locales in order
    const preferredLocales = ['ar_EG', 'ar-EG', 'ar_SA', 'ar-SA', 'ar'];

    // Check for preferred locales
    for (final preferred in preferredLocales) {
      for (final locale in locales) {
        if (locale.localeId == preferred) {
          return preferred;
        }
      }
    }

    // Fallback to any Arabic locale
    for (final locale in locales) {
      if (locale.localeId.startsWith('ar')) {
        return locale.localeId;
      }
    }

    // Ultimate fallback
    return 'ar_EG';
  }

  Future<void> _loadAudioResources() async {
    try {
      // Load audio in parallel with optimized settings
      await Future.wait([
        _correctSound.setSource(AssetSource('audio/correct-answer.wav')),
        _wrongSound.setSource(AssetSource('audio/wrong-answer.wav')),
        _listeningSound.setSource(AssetSource('audio/listening_start.wav')),
      ]);
    } catch (e) {
      print('Failed to load audio resources: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInit) {
      _didInit = true;

      // Load image with optimized approach
      _loadOptimizedRandomImage();

      // Clear unused memory to optimize RAM usage
      SchedulerBinding.instance.addPostFrameCallback((_) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
    }
  }

  // Load random image with optimized selection strategy
  Future<void> _loadOptimizedRandomImage() async {
    try {
      // Select category based on level with predefined settings
      List<String> categories = List.from(_basicCategories);
      if (widget.level >= 4) {
        categories.addAll(_advancedCategories);
      }

      _category = categories[Random().nextInt(categories.length)];

      // Get available types in this category
      final types = await _imageService.getTypesInCategory(_category);
      if (types.isEmpty) {
        throw Exception('No image types available for category $_category');
      }

      // Select a type that has a translation - use optimized approach
      // that avoids excessive random selections
      _correctType = _selectTypeWithTranslation(types, _category);

      // Get Arabic translation
      _arabicName =
          _translationHelper.getArabicTranslation(_correctType, _category);

      // Get image URL - do this in parallel with precaching
      _imageUrl =
          (await _imageService.getRandomImage(_category, _correctType))!;

      if (mounted) {
        // Prefetch the image with high priority
        final imageFuture = precacheImage(NetworkImage(_imageUrl), context);

        // Prepare TTS in parallel with image loading
        final ttsFuture = widget.ttsService.prefetchDynamic(["ما هذه الصورة؟"]);

        // Wait for critical resources
        await Future.wait([imageFuture, ttsFuture]);

        // Set loading to false
        _isLoadingNotifier.value = false;

        // Speak instruction after short delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.ttsService.speak("ما هذه الصورة؟");
          }
        });
      }
    } catch (e) {
      print('Error loading random image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading game: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  // Optimized selection of image type that has a translation
  String _selectTypeWithTranslation(List<String> types, String category) {
    // Shuffle once for randomization with reduced overhead
    final shuffledTypes = List<String>.from(types)..shuffle();

    // Try to find types with translations first (limited attempts)
    final attemptLimit = min(5, shuffledTypes.length);

    for (int i = 0; i < attemptLimit; i++) {
      final type = shuffledTypes[i];
      if (_translationHelper.getArabicTranslation(type, category) != null) {
        return type;
      }
    }

    // Fallback to any type if no translation found
    return shuffledTypes.first;
  }

  void _onSpeechStatus(String status) {
    _isListeningNotifier.value = status == 'listening';
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_hasGuessed) return;

    final String recognized = result.recognizedWords.toLowerCase();
    final double confidence = result.confidence;

    _currentWordNotifier.value = recognized;
    _confidenceNotifier.value = confidence;

    // Check answer with optimized matching using static helper
    final bool isCorrect =
        _translationHelper.isCorrectAnswer(recognized, _correctType, _category);

    // Handle guess based on correctness or high confidence
    if (isCorrect || confidence > 0.7) {
      _handleGuess(isCorrect);
    }
  }

  // Handle user's guess with optimized animation sequence
  void _handleGuess(bool isCorrect) async {
    if (_hasGuessed) return;
    _hasGuessed = true;

    // Stop speech recognition
    await _speech.stop();
    _isListeningNotifier.value = false;

    // Create a completer to track animations
    _animationCompleter = Completer<void>();

    // Update UI state
    _isCorrectNotifier.value = isCorrect;

    if (isCorrect) {
      // Show win animation
      _showWinAnimationNotifier.value = true;

      // Play correct sound
      await _playSound(_correctSound);

      // Animate scale with optimized animation
      _animateScale();

      // Speak feedback
      await widget.ttsService.speak("برافو! أحسنت");

      // Wait for animation to complete
      await _animationCompleter?.future;

      // Signal completion with high performance callback
      widget.onCorrect(1);
    } else {
      // Play wrong sound
      await _playSound(_wrongSound);

      // Prepare feedback message with both languages
      final feedback = _arabicName != null
          ? "لا، هذا ${_correctType.replaceAll('_', ' ')} - $_arabicName"
          : "لا، هذا ${_correctType.replaceAll('_', ' ')}";

      // Speak feedback
      await widget.ttsService.speak(feedback);

      // Wait before signaling failure
      await Future.delayed(const Duration(seconds: 2));

      widget.onWrong();
    }
  }

  // Optimized scale animation with frame scheduling
  void _animateScale() {
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

  // Optimized sound playback with proper resource management
  Future<void> _playSound(AudioPlayer player) async {
    await player.stop();
    await Future.delayed(const Duration(milliseconds: 30));
    await player.resume();

    return _waitForPlayer(player);
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

    // Short timeout for better performance
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await sub.cancel();
  }

  // Start speech recognition with optimized locale selection
  void _startListening() async {
    if (_isListeningNotifier.value || _hasGuessed) return;

    // Play listening sound
    await _playSound(_listeningSound);

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: _speechLocale ?? 'ar_EG', // Use pre-selected locale
        cancelOnError: true,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error with speech recognition: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Clean up all resources efficiently
    _pulseController.dispose();

    // Dispose audio resources in parallel
    _correctSound.dispose();
    _wrongSound.dispose();
    _listeningSound.dispose();

    // Cancel speech recognition
    _speech.cancel();

    // Dispose notifiers
    _isLoadingNotifier.dispose();
    _isListeningNotifier.dispose();
    _showWinAnimationNotifier.dispose();
    _currentWordNotifier.dispose();
    _isCorrectNotifier.dispose();
    _confidenceNotifier.dispose();
    _animationScaleNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
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
              const Text(
                "ما هذه الصورة؟",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildImage(),
              const SizedBox(height: 30),
              _buildSpeechButton(),
              const SizedBox(height: 20),
              _buildRecognizedText(),
              const SizedBox(height: 20),
              _buildHint(),
              const SizedBox(height: 60),
            ],
          ),
        ),
        _buildWinAnimation(),
      ],
    );
  }

  // Optimized image display with cached network image
  Widget _buildImage() {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _animationScaleNotifier,
        builder: (context, scale, _) {
          return AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutQuad,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 500, // Optimize memory usage
                  memCacheHeight: 500,
                  fadeOutDuration: const Duration(milliseconds: 50),
                  fadeInDuration: const Duration(milliseconds: 50),
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Speech button with optimized animations
  Widget _buildSpeechButton() {
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _isListeningNotifier,
        builder: (context, isListening, _) {
          return ValueListenableBuilder<bool?>(
            valueListenable: _isCorrectNotifier,
            builder: (context, isCorrect, _) {
              // Don't show button if we already have a result
              if (isCorrect != null) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 50,
                  ),
                );
              }

              return GestureDetector(
                onTap: _startListening,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    double scale = isListening
                        ? 1.0 + (_pulseController.value * 0.1)
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening ? Colors.red : Colors.blue,
                          boxShadow: [
                            BoxShadow(
                              color: (isListening ? Colors.red : Colors.blue)
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: isListening
                            ? FutureBuilder<LottieComposition>(
                                future: _listeningComposition,
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 40,
                                    );
                                  }

                                  return Lottie(
                                    composition: snapshot.data!,
                                    repeat: true,
                                    frameRate: FrameRate(
                                        60), // Lower framerate for better performance
                                  );
                                },
                              )
                            : const Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Recognition text display with optimized rebuilds
  Widget _buildRecognizedText() {
    return ValueListenableBuilder<String?>(
      valueListenable: _currentWordNotifier,
      builder: (context, currentWord, _) {
        if (currentWord == null || currentWord.isEmpty) {
          return const Text(
            "اضغط على الميكروفون وقل ما تراه في الصورة",
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          );
        }

        return ValueListenableBuilder<bool?>(
          valueListenable: _isCorrectNotifier,
          builder: (context, isCorrect, _) {
            Color textColor = Colors.black87;
            if (isCorrect != null) {
              textColor = isCorrect ? Colors.green : Colors.red;
            }

            return Text(
              currentWord,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            );
          },
        );
      },
    );
  }

  // Hint widget that shows translations - only displayed when needed
  Widget _buildHint() {
    // Only show hint if we have a translation and this is a higher level
    if (_arabicName == null ||
        _isCorrectNotifier.value != null ||
        widget.level < 3) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool?>(
      valueListenable: _isCorrectNotifier,
      builder: (context, isCorrect, _) {
        if (isCorrect != null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const Text(
                "English: ",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              Text(
                _correctType.replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "العربية: ",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              Text(
                _arabicName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Win animation with optimized rendering
  Widget _buildWinAnimation() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showWinAnimationNotifier,
      builder: (context, showWinAnimation, _) {
        if (!showWinAnimation) return const SizedBox.shrink();

        return RepaintBoundary(
          child: AnimatedOpacity(
            opacity: showWinAnimation ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: OptimizedCelebration(
              stars: _starsComposition,
              confetti: _confettiComposition,
            ),
          ),
        );
      },
    );
  }
}

// Optimized celebration component with minimal rebuilds
class OptimizedCelebration extends StatelessWidget {
  final Future<LottieComposition> stars;
  final Future<LottieComposition> confetti;

  const OptimizedCelebration({
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
          SizedBox(
            height: 120,
            child: FutureBuilder<LottieComposition>(
              future: stars,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Lottie(
                  composition: snapshot.data!,
                  repeat: false,
                  frameRate:
                      FrameRate(60), // Lower framerate for better performance
                  options: LottieOptions(
                    enableMergePaths: true,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 120,
            child: FutureBuilder<LottieComposition>(
              future: confetti,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Lottie(
                  composition: snapshot.data!,
                  repeat: false,
                  frameRate:
                      FrameRate(60), // Lower framerate for better performance
                  options: LottieOptions(
                    enableMergePaths: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
