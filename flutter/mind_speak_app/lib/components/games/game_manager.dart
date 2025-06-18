import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mind_speak_app/components/games/ImageNamingGame.dart';
import 'package:mind_speak_app/components/games/VocabularyGame.dart';
import 'package:mind_speak_app/service/avatarservice/static_translation_helper.dart';
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

  // Preloaded resources using async caching - made nullable to prevent LateInitializationError
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<int, List<Map<String, dynamic>>> _preloadedImageSets = {};
  final Map<String, List<String>> _categoryTypes = {};

  // Lottie compositions - using nullable types to prevent initialization errors
  Future<LottieComposition?>? _levelUpComposition;
  Future<LottieComposition?>? _celebrationComposition;
  Future<LottieComposition?>? _starsComposition;
  Future<LottieComposition?>? _confettiComposition;

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

  // Game stats tracking
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  int _totalScore = 0;

  // NEW: Track which game types have been played in the current session
  final Map<String, bool> _playedGameTypes = {
    'ImageRecognition': false,
    'ImageNaming': false,
    'Vocabulary': false,
    'MathFingers': false,
  };

  // NEW: Store incorrect questions to repeat them
  final List<Map<String, dynamic>> _incorrectQuestions = [];

  // NEW: Store current game data for potential repetition
  Map<String, dynamic>? _currentGameData;

  GameManager({
    required this.ttsService,
  }) {
    print("DEBUG: GameManager constructor called");
  }

  /// Preload game assets for smoother gameplay with comprehensive error handling
  Future<void> preloadGameAssets(BuildContext context) async {
    print("DEBUG: preloadGameAssets called");
    _context = context;

    // Initialize StaticTranslationHelper for games that need it
    try {
      final helper = StaticTranslationHelper.instance;
      helper.init();
    } catch (e) {
      print("Error initializing translation helper: $e");
    }

    try {
      // Preload all Lottie animations in parallel with better error handling
      final animationFutures = await Future.wait([
        AssetLottie('assets/level up.json')
            .load()
            .then((comp) => _levelUpComposition = Future.value(comp))
            .catchError((e) {
          print("Failed to load level up animation: $e");
          _levelUpComposition = Future.value(null);
          return null;
        }),
        AssetLottie('assets/celebration.json')
            .load()
            .then((comp) => _celebrationComposition = Future.value(comp))
            .catchError((e) {
          print("Failed to load celebration animation: $e");
          _celebrationComposition = Future.value(null);
          return null;
        }),
        AssetLottie('assets/more stars.json')
            .load()
            .then((comp) => _starsComposition = Future.value(comp))
            .catchError((e) {
          print("Failed to load stars animation: $e");
          _starsComposition = Future.value(null);
          return null;
        }),
        AssetLottie('assets/Confetti.json')
            .load()
            .then((comp) => _confettiComposition = Future.value(comp))
            .catchError((e) {
          print("Failed to load confetti animation: $e");
          _confettiComposition = Future.value(null);
          return null;
        }),
        AssetLottie('assets/listening_animation.json').load().catchError((e) {
          print("Failed to load listening animation: $e");
          return null;
        }),
      ], eagerError: false);

      print(
          "Animation loading completed with ${animationFutures.where((f) => f != null).length} successful loads");
    } catch (e) {
      print("Error loading animations: $e");
      // Initialize with null values to prevent errors
      _levelUpComposition = Future.value(null);
      _celebrationComposition = Future.value(null);
      _starsComposition = Future.value(null);
      _confettiComposition = Future.value(null);
    }

    // Preload audio assets with error handling
    try {
      _audioPlayers['correct'] = AudioPlayer();
      _audioPlayers['wrong'] = AudioPlayer();
      _audioPlayers['levelUp'] = AudioPlayer();
      _audioPlayers['celebration'] = AudioPlayer();
      _audioPlayers['listening'] = AudioPlayer();

      await Future.wait([
        _audioPlayers['correct']!
            .setSource(AssetSource('audio/correct-answer.wav'))
            .catchError((e) {
          print("Failed to load correct sound: $e");
          return null;
        }),
        _audioPlayers['wrong']!
            .setSource(AssetSource('audio/wrong-answer.wav'))
            .catchError((e) {
          print("Failed to load wrong sound: $e");
          return null;
        }),
        _audioPlayers['levelUp']!
            .setSource(AssetSource('audio/completion-of-level.wav'))
            .catchError((e) {
          print("Failed to load level up sound: $e");
          return null;
        }),
        _audioPlayers['celebration']!
            .setSource(AssetSource('audio/celebrationAudio.mp3'))
            .catchError((e) {
          print("Failed to load celebration sound: $e");
          return null;
        }),
        _audioPlayers['listening']!
            .setSource(AssetSource('audio/listening_start.wav'))
            .catchError((e) {
          print("Failed to load listening sound: $e");
          return null;
        }),
      ], eagerError: false);
    } catch (e) {
      print("Error loading audio resources: $e");
    }

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
    try {
      precacheImage(AssetImage(asset), context,
          onError: (exception, stackTrace) {
        print("Failed to precache $asset: $exception");
      });
    } catch (e) {
      print("Error precaching asset $asset: $e");
    }
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
    try {
      final categories = [
        'Animals',
        'Fruits',
        'Body_Parts',
        'Fingers',
        'Vehicles',
      ];

      List<Future<void>> futures = [];
      for (final category in categories) {
        futures.add(_imageService.getTypesInCategory(category).then((types) {
          _categoryTypes[category] = types;
        }).catchError((e) {
          print("Error loading types for category $category: $e");
          _categoryTypes[category] = [];
          return [];
        }));
      }

      await Future.wait(futures, eagerError: false);
    } catch (e) {
      print("Error preloading game categories: $e");
    }
  }

  /// Preload images for specific level
  Future<void> _preloadLevel(int level) async {
    try {
      if (_preloadedImageSets.containsKey(level)) return;

      // Choose a random category
      final categories = ['Animals', 'Fruits', 'Body_Parts'];
      if (categories.isEmpty) return;

      final selectedCategory = categories[Random().nextInt(categories.length)];

      // Get types efficiently
      final types = _categoryTypes[selectedCategory] ??
          await _imageService
              .getTypesInCategory(selectedCategory)
              .catchError((e) {
            print("Error getting types for $selectedCategory: $e");
            return <String>[];
          });

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
            final url = img['url'] as String? ?? '';
            if (url.isNotEmpty) {
              precacheImage(NetworkImage(url), _context, onError: (e, s) {
                // Silent fallback
                print("Error precaching image $url: $e");
              });
            }
          }
        }

        // Prefetch TTS prompts for faster experience
        try {
          await ttsService.prefetchDynamic(
              ["فين الـ ${selectedType}؟", "برافو! أحسنت", "حاول تاني"]);
        } catch (e) {
          print("Error prefetching TTS prompts: $e");
        }
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
        print("Timeout getting labeled images for $category/$correctType");
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
      print("Error getting labeled images: $e");
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    }

    return completer.future;
  }

  /// Start a game with a specific level
  void startGame(BuildContext context, int level) {
    print(
        "DEBUG: Starting game at level $level, isGameInProgress=$_isGameInProgress");

    if (_isGameInProgress) {
      print("DEBUG: Game already in progress, ignoring startGame call");
      return;
    }

    _isGameInProgress = true;
    _context = context;
    _currentLevelNotifier.value = level;
    _gameStartTime = DateTime.now();

    // Reset game stats
    print("DEBUG: Resetting game stats");
    _correctAnswers = 0;
    _wrongAnswers = 0;
    _totalScore = 0;

    // NEW: Reset game type tracking to ensure all types are played in the new session
    _playedGameTypes.forEach((key, value) => _playedGameTypes[key] = false);

    // NEW: Clear any stored incorrect questions
    _incorrectQuestions.clear();

    // Notify listeners about the reset stats
    if (onGameStatsUpdated != null) {
      print("DEBUG: Initial game stats update with zeros");
      onGameStatsUpdated!(0, 0, 0);
    }

    // Try to preload next level in the background
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _preloadLevel(level + 1);
    });

    // Show the first mini-game
    _showRandomMiniGame();
  }

  /// This method gets called to start the next mini-game
  void showNextMiniGame() {
    if (!_isGameInProgress) {
      print("DEBUG: Showing next mini-game");
      _showRandomMiniGame();
    } else {
      print("DEBUG: Game already in progress, not showing next mini-game");
    }
  }

  /// Show a random mini-game based on the current level with new game rotation logic
  void _showRandomMiniGame() async {
    if (!_context.mounted) {
      _isGameInProgress = false;
      print("DEBUG: Context not mounted, canceling game");
      return;
    }

    // NEW: Check if we have any incorrect questions to repeat
    if (_incorrectQuestions.isNotEmpty) {
      print("DEBUG: Repeating an incorrect question");
      _showRepeatQuestion();
      return;
    }

    MiniGameBase game;
    final currentLevel = _currentLevelNotifier.value;
    print("DEBUG: Showing random mini-game for level $currentLevel");

    try {
      // NEW: First check if all game types have been played
      bool allTypesPlayed = !_playedGameTypes.values.contains(false);

      // If all types have been played, reset the tracking
      if (allTypesPlayed) {
        print("DEBUG: All game types have been played, resetting tracking");
        _playedGameTypes.forEach((key, value) => _playedGameTypes[key] = false);
      }

      // Get list of unplayed game types
      List<String> unplayedTypes = _playedGameTypes.entries
          .where((entry) => entry.value == false)
          .map((entry) => entry.key)
          .toList();

      // Choose an unplayed game type with special handling for math games
      final random = Random();
      String selectedGameType;

      // Math games are level-specific (5-7), so handle them specially
      if (currentLevel >= 5 &&
          currentLevel <= 7 &&
          !_playedGameTypes['MathFingers']!) {
        selectedGameType = 'MathFingers';
      } else {
        // Filter out MathFingers for lower levels
        if (currentLevel < 5) {
          unplayedTypes.remove('MathFingers');
        }

        // If we've filtered all types, reset and try again
        if (unplayedTypes.isEmpty) {
          _playedGameTypes
              .forEach((key, value) => _playedGameTypes[key] = false);
          unplayedTypes = _playedGameTypes.keys.toList();
          if (currentLevel < 5) {
            unplayedTypes.remove('MathFingers');
          }
        }

        selectedGameType = unplayedTypes[random.nextInt(unplayedTypes.length)];
      }

      print("DEBUG: Selected game type: $selectedGameType");

      // Create the selected game type
      switch (selectedGameType) {
        case 'MathFingers':
          game = MathFingersGame(
            key: UniqueKey(),
            level: currentLevel,
            ttsService: ttsService,
            onCorrect: _handleCorrectAnswer,
            onWrong: () {
              _handleWrongAnswerWithMemory('MathFingers');
            },
          );
          break;
        case 'ImageNaming':
          game = ImageNamingGame(
            key: UniqueKey(),
            level: currentLevel,
            ttsService: ttsService,
            onCorrect: _handleCorrectAnswer,
            onWrong: () {
              _handleWrongAnswerWithMemory('ImageNaming');
            },
          );
          break;
        case 'Vocabulary':
          final helper = StaticTranslationHelper.instance;
          helper.init();

          final categories = helper.getCategories();
          if (categories.isEmpty) {
            throw Exception("No vocabulary categories available");
          }

          final selectedCategory =
              categories[random.nextInt(categories.length)];

          game = VocabularyGame(
            key: UniqueKey(),
            category: selectedCategory,
            level: currentLevel,
            numberOfOptions: min(4, currentLevel + 1),
            ttsService: ttsService,
            onCorrect: _handleCorrectAnswer,
            onWrong: () {
              _handleWrongAnswerWithMemory('Vocabulary');
            },
          );
          break;
        case 'ImageRecognition':
        default:
          if (_preloadedImageSets.containsKey(currentLevel)) {
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
            onWrong: () {
              _handleWrongAnswerWithMemory('ImageRecognition');
            },
          );
      }

      // Mark this game type as played
      _playedGameTypes[selectedGameType] = true;

      // Store current game data for potential repetition
      _storeCurrentGameData(selectedGameType, game);

      if (_context.mounted) {
        _showGameModal(game);
        print("DEBUG: Showed game modal");
      } else {
        _isGameInProgress = false;
        print("DEBUG: Context not mounted after game setup, canceling");
      }
    } catch (e) {
      print("ERROR: Error showing mini game: $e");
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
    try {
      final categories = ['Animals', 'Fruits', 'Body_Parts'];
      if (categories.isEmpty) {
        throw Exception("No categories available for image recognition");
      }

      final selectedCategory = categories[Random().nextInt(categories.length)];

      final types = _categoryTypes[selectedCategory] ??
          await _imageService
              .getTypesInCategory(selectedCategory)
              .catchError((e) {
            print("Error getting types for $selectedCategory: $e");
            return <String>[];
          });

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
            const SnackBar(
                content: Text("❌ Not enough images for this level.")),
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
          final url = img['url'] as String? ?? '';
          if (url.isNotEmpty) {
            futures.add(
                precacheImage(NetworkImage(url), _context, onError: (e, s) {
              // Silent fallback
              print("Error precaching image $url: $e");
            }));
          }
        }
        // Wait for at least some images to be loaded
        await Future.wait(futures, eagerError: false);
      }
    } catch (e) {
      print("Error preparing image recognition game: $e");
      _cachedImages = [];
      _cachedCategory = 'Animals';
      _cachedType = 'Unknown';
    }
  }

  /// Show the game in a modal bottom sheet
  void _showGameModal(MiniGameBase game) {
    if (!_context.mounted) {
      _isGameInProgress = false;
      print("DEBUG: Context not mounted, can't show game modal");
      return;
    }

    try {
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
        print("DEBUG: Game modal closed");
        _isGameInProgress = false;
      });
    } catch (e) {
      print("ERROR: Error showing game modal: $e");
      _isGameInProgress = false;
    }
  }

  /// Handle correct answer from a game
  Future<void> _handleCorrectAnswer(int points) async {
    print("DEBUG: _handleCorrectAnswer called with points: $points");
    print("DEBUG: Current total score before update: $_totalScore");
    print("DEBUG: Current correctAnswers before update: $_correctAnswers");

    if (!_context.mounted) {
      _isGameInProgress = false;
      print("DEBUG: Context not mounted in _handleCorrectAnswer");
      return;
    }

    // Update game stats
    _correctAnswers++;
    _totalScore += points;
    print("DEBUG: New total score after update: $_totalScore");
    print("DEBUG: New correctAnswers after update: $_correctAnswers");

    if (onGameStatsUpdated != null) {
      print(
          "DEBUG: Calling onGameStatsUpdated with totalScore=$_totalScore, correctAnswers=$_correctAnswers, wrongAnswers=$_wrongAnswers");
      onGameStatsUpdated!(_totalScore, _correctAnswers, _wrongAnswers);
    } else {
      print("DEBUG: onGameStatsUpdated is null, not calling");
    }

    final isLastLevel = _currentLevelNotifier.value >= _maxLevel;
    print(
        "DEBUG: isLastLevel=$isLastLevel, currentLevel=${_currentLevelNotifier.value}, maxLevel=$_maxLevel");

    if (!isLastLevel) {
      // Increment level
      _currentLevelNotifier.value++;
      print("DEBUG: Incremented level to ${_currentLevelNotifier.value}");
      _cachedImages = null;

      // Prepare next level in background
      _prepareNextLevel();
    }

    try {
      // Close the game modal first for better transition
      print("DEBUG: Closing game modal");
      Navigator.pop(_context);
    } catch (e) {
      print("ERROR: Error closing game modal: $e");
    }

    // Call the callback with the game result
    if (onGameCompleted != null) {
      print(
          "DEBUG: Calling onGameCompleted with points=$points, isLastLevel=$isLastLevel");
      onGameCompleted!(points, isLastLevel);
    } else {
      print("DEBUG: onGameCompleted is null, not calling");
    }

    // Ensure we're not already showing an animation
    if (_isShowingAnimation) {
      print("DEBUG: Animation already showing, not showing another");
      return;
    }

    // Show level completion animation
    try {
      print("DEBUG: Showing level completion animation");
      await showLevelCompletionAnimation(isLastLevel);
    } catch (e) {
      print("ERROR: Error showing level completion animation: $e");
    }

    // After animation completes, show next level if needed
    if (!isLastLevel && _context.mounted) {
      // Use frame sync for smoother transition
      print("DEBUG: Scheduling next mini-game after animation");
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _showRandomMiniGame();
        });
      });
    } else {
      print("DEBUG: Game sequence complete or context not mounted");
      _isGameInProgress = false;
    }
  }

  Future<void> _prepareNextLevel() async {
    try {
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
          ttsService.prefetchDynamic(["برافو! أحسنت"]).catchError((e) {
            print("Error prefetching TTS: $e");
          });
        }
      });
    } catch (e) {
      print("Error preparing next level: $e");
    }
  }

  /// Regular wrong answer handler - called by _handleWrongAnswerWithMemory
  void _handleWrongAnswer() {
    print("DEBUG: _handleWrongAnswer called");

    if (!_context.mounted) {
      _isGameInProgress = false;
      print("DEBUG: Context not mounted in _handleWrongAnswer");
      return;
    }

    // Update game stats
    _wrongAnswers++;
    print("DEBUG: Incremented wrong answers to: $_wrongAnswers");

    if (onGameStatsUpdated != null) {
      print("DEBUG: Calling onGameStatsUpdated");
      onGameStatsUpdated!(_totalScore, _correctAnswers, _wrongAnswers);
    } else {
      print("DEBUG: onGameStatsUpdated is null, not calling");
    }

    try {
      // Close the game modal
      print("DEBUG: Closing game modal");
      Navigator.pop(_context);
    } catch (e) {
      print("ERROR: Error closing game modal: $e");
    }

    // Call the callback for wrong answer
    if (onGameFailed != null) {
      print("DEBUG: Calling onGameFailed");
      onGameFailed!();
    } else {
      print("DEBUG: onGameFailed is null, not calling");
    }

    // With the repetition system, we'll manage showing the next game ourselves
    // so we don't need to call _showRandomMiniGame() here

    // Use frame sync for smoother transition
    print("DEBUG: Scheduling next mini-game after wrong answer");
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
        const Duration(milliseconds: 600),
        () {
          // Reset game state before showing next mini game
          _isGameInProgress = false;
          // Show the next mini-game (which will check for incorrect questions first)
          _showRandomMiniGame();
        },
      );
    });
  }

  /// NEW: Handle wrong answer and store the question for repetition
  void _handleWrongAnswerWithMemory(String gameType) {
    print("DEBUG: _handleWrongAnswerWithMemory called for $gameType");

    // Store the current game data for later repetition
    if (_currentGameData != null) {
      _incorrectQuestions.add(_currentGameData!);
      print(
          "DEBUG: Added incorrect question for repetition, queue size: ${_incorrectQuestions.length}");
    } else {
      print("DEBUG: No current game data to store for repetition");
    }

    // Call the regular wrong answer handler
    _handleWrongAnswer();
  }

  /// NEW: Store current game data for potential repetition
  void _storeCurrentGameData(String gameType, MiniGameBase game) {
    // Create a different storage structure based on game type
    Map<String, dynamic> gameData = {
      'gameType': gameType,
    };

    // Store game-specific data
    switch (gameType) {
      case 'ImageRecognition':
        // Store all the data needed to recreate this exact game
        gameData['category'] = _cachedCategory;
        gameData['type'] = _cachedType;
        gameData['images'] = _cachedImages;
        gameData['level'] = _currentLevelNotifier.value;
        break;
      case 'ImageNaming':
        // Try to extract data from the game instance
        try {
          if (game is ImageNamingGame) {
            // NOTE: We would need to add these getter properties to ImageNamingGame class
            // gameData['imageUrl'] = game.imageUrl;
            // gameData['correctType'] = game.correctType;
            // gameData['arabicType'] = game.arabicType;
            gameData['level'] = _currentLevelNotifier.value;
          }
        } catch (e) {
          print("ERROR: Failed to extract ImageNaming game data: $e");
        }
        break;
      case 'Vocabulary':
        try {
          if (game is VocabularyGame) {
            // NOTE: We would need to add these getter properties to VocabularyGame class
            gameData['category'] = game.category;
            // gameData['targetWord'] = game.targetWord;
            // gameData['targetTranslation'] = game.targetTranslation;
            // gameData['options'] = game.options;
            gameData['level'] = _currentLevelNotifier.value;
          }
        } catch (e) {
          print("ERROR: Failed to extract Vocabulary game data: $e");
        }
        break;
      case 'MathFingers':
        try {
          if (game is MathFingersGame) {
            // NOTE: We would need to add these getter properties to MathFingersGame class
            // gameData['num1'] = game.num1;
            // gameData['num2'] = game.num2;
            // gameData['operator'] = game.operator;
            gameData['level'] = _currentLevelNotifier.value;
          }
        } catch (e) {
          print("ERROR: Failed to extract MathFingers game data: $e");
        }
        break;
    }

    // Only store if we have useful data
    if (gameData.length > 2) {
      // More than just gameType and level
      _currentGameData = gameData;
      print(
          "DEBUG: Stored current game data for potential repetition: $gameType");
    } else {
      _currentGameData = null;
      print("DEBUG: Not enough game data to store");
    }
  }

  /// NEW: Show a repeated question that was previously answered incorrectly
  void _showRepeatQuestion() {
    if (_incorrectQuestions.isEmpty) {
      print("DEBUG: No incorrect questions to repeat");
      _showRandomMiniGame();
      return;
    }

    // Get the first incorrect question
    final questionData = _incorrectQuestions.removeAt(0);
    final gameType = questionData['gameType'] as String;

    print("DEBUG: Repeating a $gameType question");

    // Create a game based on the stored data
    MiniGameBase game;

    try {
      switch (gameType) {
        case 'ImageRecognition':
          // We can fully recreate ImageRecognition games
          game = ImageRecognitionGame(
              key: UniqueKey(),
              category: questionData['category'] as String,
              type: questionData['type'] as String,
              level: questionData['level'] as int,
              ttsService: ttsService,
              images: (questionData['images'] as List<Map<String, dynamic>>),
              onCorrect: _handleCorrectAnswer,
              onWrong: () {
                _handleWrongAnswerWithMemory('ImageRecognition');
              });
          break;
        case 'ImageNaming':
          // Fallback to a new random game for now
          print(
              "DEBUG: ImageNaming repeat not fully implemented, showing random game");
          _showRandomMiniGame();
          return;
        case 'Vocabulary':
          // For vocabulary, we can use category and level
          if (questionData.containsKey('category')) {
            game = VocabularyGame(
                key: UniqueKey(),
                category: questionData['category'] as String,
                level: questionData['level'] as int,
                numberOfOptions: min(4, (questionData['level'] as int) + 1),
                ttsService: ttsService,
                onCorrect: _handleCorrectAnswer,
                onWrong: () {
                  _handleWrongAnswerWithMemory('Vocabulary');
                }); // Fixed the closing parenthesis and removed the extra comma
          } else {
            print(
                "DEBUG: Vocabulary repeat missing category data, showing random game");
            _showRandomMiniGame();
            return;
          }
          break;
        case 'MathFingers':
          // For math game, level is enough to recreate similar difficulty
          game = MathFingersGame(
              key: UniqueKey(),
              level: questionData['level'] as int,
              ttsService: ttsService,
              onCorrect: _handleCorrectAnswer,
              onWrong: () {
                _handleWrongAnswerWithMemory('MathFingers');
              });
          break;
        default:
          print("DEBUG: Unknown game type for repetition: $gameType");
          _showRandomMiniGame();
          return;
      }

      // Store current game data for potential future repetition
      _currentGameData = questionData;

      if (_context.mounted) {
        _showGameModal(game);
        print("DEBUG: Showed repeated game modal");
      } else {
        _isGameInProgress = false;
        print("DEBUG: Context not mounted after repeated game setup");
      }
    } catch (e) {
      print("ERROR: Error showing repeated game: $e");
      _isGameInProgress = false;

      // Try showing a new random game instead
      _showRandomMiniGame();
    }
  }

  /// Show level completion animation with improved performance and error handling
  Future<void> showLevelCompletionAnimation(bool isLastLevel) async {
    if (!_context.mounted || _isShowingAnimation) {
      print("DEBUG: Context not mounted or animation already showing");
      return;
    }

    print(
        "DEBUG: Starting level completion animation, isLastLevel=$isLastLevel");
    _isShowingAnimation = true;
    _animationCompleter = Completer<void>();

    final overlay = Overlay.of(_context);
    OverlayEntry? overlayEntry;

    try {
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
                    FutureBuilder<LottieComposition?>(
                      future: isLastLevel
                          ? _celebrationComposition
                          : _levelUpComposition,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) {
                          // Fallback when animation is not available
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isLastLevel
                                      ? Icons.celebration
                                      : Icons.arrow_upward,
                                  size: 80,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 20),
                                const CircularProgressIndicator(
                                    color: Colors.white),
                              ],
                            ),
                          );
                        }

                        return Lottie(
                          composition: snapshot.data!,
                          height: 200,
                          repeat: true,
                          frameRate: FrameRate(
                              60), // Lower frame rate for better performance
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
      print("DEBUG: Level completion animation overlay inserted");

      try {
        // Use a fresh AudioPlayer for reliable playback
        final soundPlayer = AudioPlayer();
        await soundPlayer
            .setSource(AssetSource(
          isLastLevel
              ? 'audio/celebrationAudio.mp3'
              : 'audio/completion-of-level.wav',
        ))
            .catchError((e) {
          print("Error setting audio source: $e");
        });

        // Small delay for better audio-visual sync
        await Future.delayed(const Duration(milliseconds: 50));
        await soundPlayer.resume().catchError((e) {
          print("Error playing sound: $e");
        });

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
      if (_context.mounted) {
        // Create fade out animation
        for (double opacity = 1.0; opacity > 0; opacity -= 0.1) {
          if (!_context.mounted) break;

          await Future.delayed(const Duration(milliseconds: 20));
        }

        // Remove overlay
        overlayEntry.remove();
        overlayEntry = null;
        print("DEBUG: Removed animation overlay");
      }
    } catch (e) {
      print("ERROR: Error in level completion animation: $e");

      // Make sure to remove overlay entry if it exists
      if (overlayEntry != null) {
        try {
          overlayEntry.remove();
        } catch (e2) {
          print("Error removing overlay: $e2");
        }
      }

      // Ensure we still complete the animation flow
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    _isShowingAnimation = false;
    _animationCompleter?.complete();
    print("DEBUG: Level completion animation finished");
  }

  // Current level getter for external access
  int get currentLevel => _currentLevelNotifier.value;

  // Game stats getters
  int get correctAnswers => _correctAnswers;
  int get wrongAnswers => _wrongAnswers;
  int get totalScore => _totalScore;

  // Check if game is in progress
  bool get isGameInProgress => _isGameInProgress;

  // Max level getter
  int get maxLevel => _maxLevel;

  /// Reset the game to level 1
  void resetGame() {
    print("DEBUG: resetGame called - resetting all game state");
    _currentLevelNotifier.value = 1;
    _correctAnswers = 0;
    _wrongAnswers = 0;
    _totalScore = 0;
    _cachedImages = null;
    _gameStartTime = null;
    _isGameInProgress = false;

    // Reset game type tracking
    _playedGameTypes.forEach((key, value) => _playedGameTypes[key] = false);

    // Clear incorrect questions queue
    _incorrectQuestions.clear();
    _currentGameData = null;
  }

  /// Clean up all resources
  void dispose() {
    print("DEBUG: GameManager dispose called");
    try {
      // Cancel timer
      _cacheRefreshTimer?.cancel();

      // Release audio resources
      for (final player in _audioPlayers.values) {
        player.dispose();
      }

      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      print("Error disposing GameManager resources: $e");
    }
  }
}
