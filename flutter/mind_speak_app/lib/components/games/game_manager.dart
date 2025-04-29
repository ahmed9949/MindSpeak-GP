import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:mind_speak_app/components/games/image_recognition_game.dart';
import 'package:mind_speak_app/components/games/math_fingers_game.dart';

class GameManager {
  final ChatGptTtsService ttsService;
  final GameImageService _imageService = GameImageService();

  // Game state with value notifiers for reactivity
  final ValueNotifier<int> _currentLevelNotifier = ValueNotifier(1);
  final int _maxLevel = 7;
  DateTime? _gameStartTime;

  // Preloaded resources using async caching
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<int, List<Map<String, dynamic>>> _preloadedImageSets = {};
  final Map<String, List<String>> _categoryTypes = {};

  // Lottie compositions preloaded for better performance
  late Future<LottieComposition> _levelUpComposition;
  late Future<LottieComposition> _celebrationComposition;
  late Future<LottieComposition> _starsComposition;
  late Future<LottieComposition> _confettiComposition;

  // Cache for image recognition games
  List<Map<String, dynamic>>? _cachedImages;
  String? _cachedCategory;
  String? _cachedType;

  // Cache invalidation timer
  Timer? _cacheRefreshTimer;

  // Callback functions
  Function(int score, bool isLastLevel)? onGameCompleted;
  Function()? onGameFailed;
  Function(int totalScore, int correctAnswers, int wrongAnswers)?
      onGameStatsUpdated;

  // Context reference
  late BuildContext _context;

  // Animation-related variables
  Completer<void>? _animationCompleter;
  bool _isShowingAnimation = false;

  // Flag to prevent multiple game instances
  bool _isGameInProgress = false;

  GameManager({
    required this.ttsService,
  });

  /// Preload game assets for smoother gameplay
  Future<void> preloadGameAssets(BuildContext context) async {
    _context = context;

    // Preload all Lottie animations in parallel
    await Future.wait([
      AssetLottie('assets/level up.json')
          .load()
          .then((comp) => _levelUpComposition = Future.value(comp)),
      AssetLottie('assets/celebration.json')
          .load()
          .then((comp) => _celebrationComposition = Future.value(comp)),
      AssetLottie('assets/more stars.json')
          .load()
          .then((comp) => _starsComposition = Future.value(comp)),
      AssetLottie('assets/Confetti.json')
          .load()
          .then((comp) => _confettiComposition = Future.value(comp)),
    ]);

    // Preload audio assets in parallel
    _audioPlayers['correct'] = AudioPlayer();
    _audioPlayers['wrong'] = AudioPlayer();
    _audioPlayers['levelUp'] = AudioPlayer();
    _audioPlayers['celebration'] = AudioPlayer();

    await Future.wait([
      _audioPlayers['correct']!
          .setSource(AssetSource('audio/correct-answer.wav')),
      _audioPlayers['wrong']!.setSource(AssetSource('audio/wrong-answer.wav')),
      _audioPlayers['levelUp']!
          .setSource(AssetSource('audio/completion-of-level.wav')),
      _audioPlayers['celebration']!
          .setSource(AssetSource('audio/celebrationAudio.mp3')),
    ]);

    // Preload animation assets with higher priority
    await Future.wait([
      _precacheAssetWithPriority('assets/level up.json', context),
      _precacheAssetWithPriority('assets/celebration.json', context),
      _precacheAssetWithPriority('assets/more stars.json', context),
      _precacheAssetWithPriority('assets/Confetti.json', context),
    ]);

    // Preload categories and common image types
    await _preloadGameCategories();

    // Preload first level
    await _preloadLevel(1);

    // Setup cache refresh timer
    _setupCacheRefreshTimer();
  }

  /// Precache asset with high priority
  Future<void> _precacheAssetWithPriority(
      String asset, BuildContext context) async {
    precacheImage(AssetImage(asset), context, onError: (exception, stackTrace) {
      print("Failed to precache $asset: $exception");
    });
  }

  /// Setup timer to refresh cache periodically
  void _setupCacheRefreshTimer() {
    _cacheRefreshTimer?.cancel();
    _cacheRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_context.mounted) {
        // Preload next level in background
        _preloadLevel(_currentLevelNotifier.value + 1);
      }
    });
  }

  /// Preload categories and their types
  Future<void> _preloadGameCategories() async {
    final categories = ['Animals', 'Fruits', 'Body_Parts', 'Fingers'];

    List<Future<void>> futures = [];
    for (final category in categories) {
      futures.add(_imageService.getTypesInCategory(category).then((types) {
        _categoryTypes[category] = types;
      }));
    }

    await Future.wait(futures);
  }

  /// Preload images for specific level
  Future<void> _preloadLevel(int level) async {
    if (_preloadedImageSets.containsKey(level)) return;

    // Choose a random category
    final categories = ['Animals', 'Fruits', 'Body_Parts'];
    final selectedCategory = categories[Random().nextInt(categories.length)];

    try {
      // Get types efficiently
      final types = _categoryTypes[selectedCategory] ??
          await _imageService.getTypesInCategory(selectedCategory);

      if (types.isEmpty || types.length < level + 1) return;

      // Select random type
      final selectedType = types[Random().nextInt(types.length)];

      // Get labeled images with timeout
      final imageData = await _getLabeledImagesWithTimeout(
        category: selectedCategory,
        correctType: selectedType,
        count: level + 1,
      );

      if (imageData.length >= level + 1) {
        // Set type for correct items
        for (var item in imageData) {
          if (item['isCorrect'] == true) {
            item['type'] = selectedType;
          }
        }

        // Cache the images
        _preloadedImageSets[level] = imageData;

        // Precache images efficiently with frame sync
        if (_context.mounted) {
          for (final img in imageData) {
            final url = img['url'] as String;
            precacheImage(NetworkImage(url), _context, onError: (e, s) {
              // Silent fallback
            });
          }
        }

        // Prefetch TTS prompts for faster experience
        await ttsService.prefetchDynamic(
            ["فين الـ ${selectedType}؟", "برافو! أحسنت", "حاول تاني"]);
      }
    } catch (e) {
      print("Error preloading level $level: $e");
      // Continue without failing
    }
  }

  /// Get labeled images with timeout to prevent hangs
  Future<List<Map<String, dynamic>>> _getLabeledImagesWithTimeout({
    required String category,
    required String correctType,
    required int count,
  }) async {
    final completer = Completer<List<Map<String, dynamic>>>();

    // Set timeout
    Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    });

    // Try to get images
    try {
      final imageData = await _imageService.getLabeledImages(
        category: category,
        correctType: correctType,
        count: count,
      );

      if (!completer.isCompleted) {
        completer.complete(imageData);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    }

    return completer.future;
  }

  /// Start a game with a specific level
  void startGame(BuildContext context, int level) {
    if (_isGameInProgress) return;

    _isGameInProgress = true;
    _context = context;
    _currentLevelNotifier.value = level;
    _gameStartTime = DateTime.now();

    // Try to preload next level in the background
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _preloadLevel(level + 1);
    });

    _showRandomMiniGame();
  }

  /// Show a random mini-game based on the current level
  void _showRandomMiniGame() async {
    if (!_context.mounted) {
      _isGameInProgress = false;
      return;
    }

    MiniGameBase game;
    final currentLevel = _currentLevelNotifier.value;

    try {
      if (currentLevel == 5 || currentLevel == 6 || currentLevel == 7) {
        // Math game levels
        game = MathFingersGame(
          key: UniqueKey(),
          level: currentLevel,
          ttsService: ttsService,
          onCorrect: _handleCorrectAnswer,
          onWrong: _handleWrongAnswer,
        );
      } else {
        // Image recognition game levels
        if (_preloadedImageSets.containsKey(currentLevel)) {
          // Use preloaded images if available
          _cachedImages = _preloadedImageSets[currentLevel];
          final correctItem = _cachedImages!.firstWhere(
            (img) => img['isCorrect'] == true,
            orElse: () => {'type': 'Unknown'},
          );
          _cachedType = correctItem['type'] as String? ?? 'Unknown';
          _cachedCategory = _categoryTypes.keys.firstWhere(
            (cat) => _categoryTypes[cat]!.contains(_cachedType),
            orElse: () => 'Animals',
          );
        } else {
          // Prepare new images if needed
          if (_cachedImages == null || _cachedImages!.isEmpty) {
            await _prepareImageRecognitionGame();
            if (_cachedImages == null || !_context.mounted) {
              _isGameInProgress = false;
              return;
            }
          }
        }

        game = ImageRecognitionGame(
          key: UniqueKey(),
          category: _cachedCategory!,
          type: _cachedType!,
          level: currentLevel,
          ttsService: ttsService,
          images: _cachedImages!,
          onCorrect: _handleCorrectAnswer,
          onWrong: _handleWrongAnswer,
        );
      }

      if (_context.mounted) {
        _showGameModal(game);
      } else {
        _isGameInProgress = false;
      }
    } catch (e) {
      print("Error showing mini game: $e");
      _isGameInProgress = false;

      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(content: Text("Error loading game: $e")),
        );
      }
    }
  }

  /// Prepare images for the image recognition game
  Future<void> _prepareImageRecognitionGame() async {
    final categories = ['Animals', 'Fruits', 'Body_Parts'];
    final selectedCategory = categories[Random().nextInt(categories.length)];

    final types = _categoryTypes[selectedCategory] ??
        await _imageService.getTypesInCategory(selectedCategory);

    if (types.isEmpty || types.length < _currentLevelNotifier.value + 1) {
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough types for this level.")),
        );
      }
      return;
    }

    final selectedType = types[Random().nextInt(types.length)];

    // Get images with timeout to prevent hangs
    final imageData = await _getLabeledImagesWithTimeout(
      category: selectedCategory,
      correctType: selectedType,
      count: _currentLevelNotifier.value + 1,
    );

    if (imageData.isEmpty ||
        imageData.length < _currentLevelNotifier.value + 1) {
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough images for this level.")),
        );
      }
      return;
    }

    // Add type to each item
    for (var item in imageData) {
      if (item['isCorrect'] == true) {
        item['type'] = selectedType;
      }
    }

    _cachedImages = imageData;
    _cachedCategory = selectedCategory;
    _cachedType = selectedType;

    // Preload images for smoother display
    if (_context.mounted) {
      final futures = <Future>[];
      for (final img in imageData) {
        final url = img['url'] as String;
        futures.add(precacheImage(NetworkImage(url), _context, onError: (e, s) {
          // Silent fallback
        }));
      }
      // Wait for at least some images to be loaded
      await Future.wait(futures);
    }
  }

  /// Show the game in a modal bottom sheet
  void _showGameModal(MiniGameBase game) {
    if (!_context.mounted) {
      _isGameInProgress = false;
      return;
    }

    showModalBottomSheet(
      context: _context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(_context),
        duration: const Duration(milliseconds: 300),
      ),
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        snapSizes: const [0.6, 0.95],
        snap: true,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Provider.of<ThemeProvider>(bottomSheetContext).isDarkMode
                ? Colors.grey[900]
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: game,
        ),
      ),
    ).then((_) {
      // When modal is closed for any reason, make sure game state is reset
      _isGameInProgress = false;
    });
  }

  /// Handle correct answer from a game
  Future<void> _handleCorrectAnswer(int points) async {
    if (!_context.mounted) {
      _isGameInProgress = false;
      return;
    }

    final isLastLevel = _currentLevelNotifier.value >= _maxLevel;

    if (!isLastLevel) {
      // Increment level
      _currentLevelNotifier.value++;
      _cachedImages = null;

      // Prepare next level in background
      _prepareNextLevel();
    }

    // Close the game modal first for better transition
    Navigator.pop(_context);

    // Call the callback with the game result
    if (onGameCompleted != null) {
      onGameCompleted!(points, isLastLevel);
    }

    // Ensure we're not already showing an animation
    if (_isShowingAnimation) return;

    // Show level completion animation
    await showLevelCompletionAnimation(isLastLevel);

    // After animation completes, show next level if needed
    if (!isLastLevel && _context.mounted) {
      // Use frame sync for smoother transition
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _showRandomMiniGame();
        });
      });
    } else {
      _isGameInProgress = false;
    }
  }

  Future<void> _prepareNextLevel() async {
    if (_currentLevelNotifier.value >= _maxLevel) return;

    // Preload next level assets in background with lower priority
    SchedulerBinding.instance.scheduleTask(() {
      _preloadLevel(_currentLevelNotifier.value + 1);
      return null;
    }, Priority.animation);

    // Pre-initialize UI elements
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_context.mounted) {
        // Pre-warm animations
        _precacheAssetWithPriority('assets/level up.json', _context);

        // Prefetch TTS for next level
        ttsService.prefetchDynamic(["برافو! أحسنت"]);
      }
    });
  }

  /// Handle wrong answer from a game
  void _handleWrongAnswer() {
    if (!_context.mounted) {
      _isGameInProgress = false;
      return;
    }

    // Close the game modal
    Navigator.pop(_context);

    // Call the callback for wrong answer
    if (onGameFailed != null) {
      onGameFailed!();
    }

    // Use frame sync for smoother transition
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
        const Duration(milliseconds: 600),
        () {
          // Reset game state before showing next mini game
          _isGameInProgress = false;
          _showRandomMiniGame();
        },
      );
    });
  }

  /// Show level completion animation with improved performance
  Future<void> showLevelCompletionAnimation(bool isLastLevel) async {
    if (!_context.mounted || _isShowingAnimation) return;

    _isShowingAnimation = true;
    _animationCompleter = Completer<void>();

    final overlay = Overlay.of(_context);
    OverlayEntry? overlayEntry;

    // Create overlay with optimized rendering
    overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: RepaintBoundary(
          child: Material(
            color: Colors.black.withOpacity(0.6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Use preloaded composition for smoother animation
                  FutureBuilder<LottieComposition>(
                    future: isLastLevel
                        ? _celebrationComposition
                        : _levelUpComposition,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                        );
                      }

                      return Lottie(
                        composition: snapshot.data!,
                        height: 200,
                        repeat: true,
                        frameRate: FrameRate(60), // Higher frame rate
                        options: LottieOptions(
                          enableMergePaths: true,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (value * 0.2),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      isLastLevel ? "🎉 Well Done!" : "Level Up!",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 5.0,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    try {
      // Use a fresh AudioPlayer for reliable playback
      final soundPlayer = AudioPlayer();
      await soundPlayer.setSource(AssetSource(
        isLastLevel
            ? 'audio/celebrationAudio.mp3'
            : 'audio/completion-of-level.wav',
      ));

      // Small delay for better audio-visual sync
      await Future.delayed(const Duration(milliseconds: 50));
      await soundPlayer.resume();

      // Keep animation visible for consistent duration
      await Future.delayed(const Duration(milliseconds: 2300));

      // Clean up player
      await soundPlayer.dispose();
    } catch (e) {
      print("Error playing sound: $e");
      // Fallback delay
      await Future.delayed(const Duration(milliseconds: 2500));
    }

    // Create smooth fade-out effect
    if (_context.mounted && overlayEntry != null) {
      // Create fade out animation
      for (double opacity = 1.0; opacity > 0; opacity -= 0.1) {
        if (!_context.mounted) break;

        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Remove overlay
      overlayEntry.remove();
      overlayEntry = null;
    }

    _isShowingAnimation = false;
    _animationCompleter?.complete();
  }

  /// Clean up all resources
  void dispose() {
    // Cancel timer
    _cacheRefreshTimer?.cancel();

    // Release audio resources
    for (final player in _audioPlayers.values) {
      player.dispose();
    }

    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
