import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:mind_speak_app/service/avatarservice/game_image_service.dart';
import 'package:mind_speak_app/service/avatarservice/chatgptttsservice.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/components/games/mini_game_base.dart';
import 'package:mind_speak_app/components/games/image_recognition_game.dart';
import 'package:mind_speak_app/components/games/math_fingers_game.dart';

class GameManager {
  final ChatGptTtsService ttsService;
  final GameImageService _imageService = GameImageService();

  // Game state
  int _currentLevel = 1;
  final int _maxLevel = 7;
  // ignore: unused_field
  DateTime? _gameStartTime;

  // Preloaded resources
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<int, List<Map<String, dynamic>>> _preloadedImageSets = {};
  final Map<String, List<String>> _categoryTypes = {};

  // Cache for image recognition games
  List<Map<String, dynamic>>? _cachedImages;
  String? _cachedCategory;
  String? _cachedType;

  // Callback functions
  Function(int score, bool isLastLevel)? onGameCompleted;
  Function()? onGameFailed;
  Function(int totalScore, int correctAnswers, int wrongAnswers)?
      onGameStatsUpdated;

  // Context reference
  late BuildContext _context;

  GameManager({
    required this.ttsService,
  });

  /// Preload game assets for smoother gameplay
  Future<void> preloadGameAssets(BuildContext context) async {
    _context = context;

    // Preload audio assets
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

    // Preload animation assets
    precacheImage(const AssetImage('assets/level up.json'), context);
    precacheImage(const AssetImage('assets/celebration.json'), context);
    precacheImage(const AssetImage('assets/more stars.json'), context);
    precacheImage(const AssetImage('assets/Confetti.json'), context);

    // Preload categories and common image types
    await _preloadGameCategories();

    // Preload first level
    await _preloadLevel(1);
  }

  /// Preload categories and their types
  Future<void> _preloadGameCategories() async {
    final categories = ['Animals', 'Fruits', 'Body_Parts', 'Fingers'];

    for (final category in categories) {
      _categoryTypes[category] =
          await _imageService.getTypesInCategory(category);
    }
  }

  /// Preload images for specific level
  Future<void> _preloadLevel(int level) async {
    if (_preloadedImageSets.containsKey(level)) return;

    final categories = ['Animals', 'Fruits', 'Body_Parts'];
    final selectedCategory = categories[Random().nextInt(categories.length)];

    final types = _categoryTypes[selectedCategory] ??
        await _imageService.getTypesInCategory(selectedCategory);
    if (types.length < level + 1) return;

    final selectedType = types[Random().nextInt(types.length)];
    final imageData = await _imageService.getLabeledImages(
      category: selectedCategory,
      correctType: selectedType,
      count: level + 1,
    );

    if (imageData.length >= level + 1) {
      for (var item in imageData) {
        if (item['isCorrect'] == true) {
          item['type'] = selectedType;
        }
      }

      _preloadedImageSets[level] = imageData;

      // ✅ Precache image assets
      for (final img in imageData) {
        final url = img['url'] as String;
        precacheImage(NetworkImage(url), _context);
      }

      // ✅ Precache TTS prompts for faster experience
      await ttsService.prefetchDynamic(
          ["فين الـ ${selectedType}؟", "برافو! أحسنت", "حاول تاني"]);
    }
  }

  /// Start a game with a specific level
  void startGame(BuildContext context, int level) {
    _context = context;
    _currentLevel = level;
    _gameStartTime = DateTime.now();

    // Try to preload next level
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _preloadLevel(level + 1);
    });

    _showRandomMiniGame();
  }

  /// Show a random mini-game based on the current level
 void _showRandomMiniGame() async {
  MiniGameBase game;

  if (_currentLevel == 5 || _currentLevel == 6 || _currentLevel == 7) {
    game = MathFingersGame(
      key: UniqueKey(),
      level: _currentLevel,
      ttsService: ttsService,
      onCorrect: _handleCorrectAnswer,
      onWrong: _handleWrongAnswer,
    );
  } else {
    if (_preloadedImageSets.containsKey(_currentLevel)) {
      _cachedImages = _preloadedImageSets[_currentLevel];
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
        if (_cachedImages == null) return;
      }
    }

    game = ImageRecognitionGame(
      key: UniqueKey(),
      category: _cachedCategory!,
      type: _cachedType!,
      level: _currentLevel,
      ttsService: ttsService,
      images: _cachedImages!,
      onCorrect: _handleCorrectAnswer,
      onWrong: _handleWrongAnswer,
    );
  }

  if (_context.mounted) {
    _showGameModal(game);
  }
}


  /// Prepare images for the image recognition game
  Future<void> _prepareImageRecognitionGame() async {
    final categories = ['Animals', 'Fruits', 'Body_Parts'];
    final selectedCategory = categories[Random().nextInt(categories.length)];

    final types = _categoryTypes[selectedCategory] ??
        await _imageService.getTypesInCategory(selectedCategory);

    if (types.length < _currentLevel + 1) {
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough types for this level.")),
        );
      }
      return;
    }

    final selectedType = types[Random().nextInt(types.length)];
    print("DEBUG: Selected type: $selectedType");

    final imageData = await _imageService.getLabeledImages(
      category: selectedCategory,
      correctType: selectedType,
      count: _currentLevel + 1,
    );

    if (imageData.length < _currentLevel + 1) {
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(content: Text("❌ Not enough images for this level.")),
        );
      }
      return;
    }

    // Make sure the type is included in each item
    for (var item in imageData) {
      if (item['isCorrect'] == true) {
        item['type'] = selectedType;
      }
    }

    _cachedImages = imageData;
    _cachedCategory = selectedCategory;
    _cachedType = selectedType;

    print("DEBUG: Set cached type: $_cachedType");

    // Preload images
    if (_context.mounted) {
      for (final img in imageData) {
        final url = img['url'] as String;
        precacheImage(NetworkImage(url), _context);
      }
    }
  }

  /// Show the game in a modal bottom sheet
  void _showGameModal(MiniGameBase game) {
    showModalBottomSheet(
      context: _context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Provider.of<ThemeProvider>(bottomSheetContext).isDarkMode
                ? Colors.grey[900]
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(12),
          // Fix: Use game directly without wrapping in SingleChildScrollView
          child: game,
        ),
      ),
    );
  }

  /// Handle correct answer from a game
  Future<void> _handleCorrectAnswer(int points) async {
    final isLastLevel = _currentLevel >= _maxLevel;

    if (!isLastLevel) {
      _currentLevel++;
      _cachedImages = null;
      _prepareNextLevel();
    }

    // 1. Close the game modal first
    Navigator.pop(_context);

    // 2. Call the callback with the game result
    // This will trigger the level completion animation
    if (onGameCompleted != null) {
      onGameCompleted!(points, isLastLevel);
    }

    // 3. After level completion animation, wait for it to finish before showing next level
    if (!isLastLevel) {
      // Wait for level completion animation (now handled externally)
      // The animation takes about 2.5 seconds, so add a little extra
      await Future.delayed(const Duration(milliseconds: 3000));

      // Now show the next level
      _showRandomMiniGame();

      // Preload next level in background
      if (_currentLevel < _maxLevel) {
        _preloadLevel(_currentLevel + 1);
      }
    }
  }

  Future<void> _prepareNextLevel() async {
    if (_currentLevel >= _maxLevel) return;

    // Preload next level assets in background
    _preloadLevel(_currentLevel + 1);

    // Pre-initialize UI elements
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_context.mounted) {
        // Pre-warm next level
        precacheImage(AssetImage('assets/level up.json'), _context);
      }
    });
  }

  /// Handle wrong answer from a game
  void _handleWrongAnswer() {
    Navigator.pop(_context);

    // Call the callback for wrong answer
    if (onGameFailed != null) {
      onGameFailed!();
    }

    Future.delayed(
      const Duration(milliseconds: 600),
      _showRandomMiniGame,
    );
  }

  /// Show level completion animation (can be called from the parent)
  Future<void> showLevelCompletionAnimation(bool isLastLevel) async {
    final overlay = Overlay.of(_context);
    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: RepaintBoundary(
          child: Material(
            color: Colors.black.withOpacity(0.6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // In the builder for overlayEntry:
                Lottie.asset(
                  isLastLevel
                      ? 'assets/celebration.json'
                      : 'assets/level up.json',
                  height: 200,
                  repeat: true,
                  frameRate:
                      FrameRate(60), // Higher frame rate for smoother animation
                  options: LottieOptions(
                    enableMergePaths: true, // Better performance
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isLastLevel ? "🎉 Well Done!" : "Level Up!",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    try {
      // Create a fresh instance of AudioPlayer for more reliable playback
      final soundPlayer = AudioPlayer();

      // Play sound from asset directly rather than resuming
      await soundPlayer.play(AssetSource(
        isLastLevel
            ? 'audio/celebrationAudio.mp3'
            : 'audio/completion-of-level.wav',
      ));

      // Keep animation and sound playing for a set duration
      await Future.delayed(const Duration(milliseconds: 2500));

      // Clean up
      soundPlayer.dispose();
    } catch (e) {
      print("Error playing sound: $e");
      // Ensure we still have some delay even if sound fails
      await Future.delayed(const Duration(milliseconds: 2500));
    }

    // Remove the overlay
    overlayEntry.remove();
  }

  void dispose() {
    for (final player in _audioPlayers.values) {
      player.dispose();
    }
  }
}
