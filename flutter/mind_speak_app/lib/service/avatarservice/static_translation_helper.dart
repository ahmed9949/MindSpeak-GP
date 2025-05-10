class StaticTranslationHelper {
  // Private constructor prevents instantiation
  StaticTranslationHelper._();

  // Singleton instance
  static final StaticTranslationHelper instance = StaticTranslationHelper._();

  // Flag to track initialization
  bool _isInitialized = false;

  // Using separate maps per category improves localization and memory efficiency
  static final Map<String, String> _animals = {
    'cat': 'قطة',
    'dog': 'كلب',
    'lion': 'أسد',
    'tiger': 'نمر',
    'elephant': 'فيل',
    'monkey': 'قرد',
    'giraffe': 'زرافة',
    'rabbit': 'أرنب',
    'bear': 'دب',
    'horse': 'حصان',
    'cow': 'بقرة',
    'sheep': 'خروف',
    'goat': 'ماعز',
    'chicken': 'دجاجة',
    'duck': 'بطة',
    'bird': 'عصفور',
    'fish': 'سمكة',
    'turtle': 'سلحفاة',
    'snake': 'ثعبان',
    'frog': 'ضفدع',
    'bat': 'خفاش',
    'bee': 'نحلة',
    'butterfly': 'فراشة',
    'mouse': 'فار',
  };

  static final Map<String, String> _fruits = {
    'apple': 'تفاحة',
    'banana': 'موز',
    'orange': 'برتقان',
    'grape': 'عنب',
    'strawberry': 'فراولة',
    'watermelon': 'بطيخ',
    'pineapple': 'أناناس',
    'peach': 'خوخ',
    'mango': 'مانجا',
    'lemon': 'ليمون',
    'avocado': 'افوكادو',
    'coconut': 'جوز هند',
    'olive': 'زتون',
    'kiwi': 'كيوى',
    'pomegranate': 'رمان',
  };

  static final Map<String, String> _bodyParts = {
    'elbow': 'كوع',
    'eye': 'عين',
    'nose': 'أنف',
    'ear': 'أذن',
    'hand': 'يد',
    'foot': 'قدم',
    'neck': 'رقبة',
    'knee': 'ركبة',
  };

  static final Map<String, String> _vegetables = {
    'beetroot': 'بنجر',
    'bell pepper': 'فلفل',
    'cabbage': 'خس',
    'carrot': 'جزر',
    'cauliflower': 'قرنبيط',
    'cucumber': 'خيار',
    'eggplant': 'بتجان',
    'garlic': 'توم',
    'ginger': 'جنزبيل',
    'onion': 'بصل',
    'peas': 'بسلة',
    'potato': 'بطاطس',
    'sweet potato': 'بطاطا',
    'sweetcorn': 'درة',
    'tomato': 'طماطم',
  };

  // static final Map<String, String> _vehicles = {
  //   'car': 'سيارة',
  //   'bus': 'حافلة',
  //   'truck': 'شاحنة',
  //   'bicycle': 'دراجة',
  //   'motorcycle': 'دراجة نارية',
  //   'airplane': 'طائرة',
  //   'helicopter': 'هليكوبتر',
  //   'boat': 'قارب',
  //   'ship': 'سفينة',
  //   'train': 'قطار',
  // };

  // static final Map<String, String> _householdItems = {
  //   'chair': 'كرسي',
  //   'table': 'طاولة',
  //   'bed': 'سرير',
  //   'lamp': 'مصباح',
  //   'sofa': 'أريكة',
  //   'television': 'تلفزيون',
  //   'refrigerator': 'ثلاجة',
  //   'clock': 'ساعة',
  //   'phone': 'هاتف',
  //   'door': 'باب',
  //   'window': 'نافذة',
  // };

  // For reverse lookup (Arabic to English)
  static final Map<String, String> _reverseMap = {};

  // Maps category names to their respective translation maps
  static final Map<String, Map<String, String>> _categoryMaps = {};

  // Common synonyms for more flexible matching
  static final Map<String, List<String>> _synonyms = {
    'cat': ['بسة', 'قط'], // Alternative forms for cat
    'dog': ['كلبة'], // Female form for dog
    'chicken': ['دجاج', 'فرخة', 'فراخ'], // Variations for chicken
    'bird': ['طائر', 'عصفورة'], // Variations for bird
    'apple': ['تفاح'], // Singular/plural variations
    'banana': ['موزة'], // Singular form
  };

  // Common Arabic prefixes to check during matching
  static const List<String> _arabicPrefixes = ['ال'];

  /// Initialize the helper
  void init() {
    if (_isInitialized) return;

    // Initialize category maps for faster category-based lookups
    _categoryMaps['Animals'] = _animals;
    _categoryMaps['Fruits'] = _fruits;
    _categoryMaps['Body_Parts'] = _bodyParts;
    _categoryMaps['vegetables'] = _vegetables;

    // _categoryMaps['Vehicles'] = _vehicles;
    // _categoryMaps['Household_Items'] = _householdItems;

    // Build reverse lookup map
    _buildReverseMap();

    _isInitialized = true;
  }

  /// Build the reverse lookup map for Arabic to English translations
  void _buildReverseMap() {
    // Add all translations to the reverse map
    for (final categoryMap in _categoryMaps.values) {
      for (final entry in categoryMap.entries) {
        _reverseMap[entry.value.toLowerCase()] = entry.key.toLowerCase();
      }
    }

    // Add synonyms to reverse map
    for (final entry in _synonyms.entries) {
      for (final synonym in entry.value) {
        _reverseMap[synonym.toLowerCase()] = entry.key.toLowerCase();
      }
    }
  }

  /// Get Arabic translation for an English term
  /// Returns null if no translation is found
  String? getArabicTranslation(String englishTerm, [String? category]) {
    if (!_isInitialized) init();

    // Convert to lowercase for case-insensitive matching
    englishTerm = englishTerm.trim().toLowerCase();

    // Remove underscores
    englishTerm = englishTerm.replaceAll('_', ' ');

    // If category is provided, look only in that category
    if (category != null && _categoryMaps.containsKey(category)) {
      return _categoryMaps[category]![englishTerm];
    }

    // Otherwise, search all categories
    for (final categoryMap in _categoryMaps.values) {
      final translation = categoryMap[englishTerm];
      if (translation != null) {
        return translation;
      }
    }

    return null;
  }

  /// Get English term for an Arabic translation
  /// Returns null if no match is found
  String? getEnglishTerm(String arabicTerm) {
    if (!_isInitialized) init();

    // Convert to lowercase for case-insensitive matching
    arabicTerm = arabicTerm.trim().toLowerCase();

    // Check for direct match
    final englishTerm = _reverseMap[arabicTerm];
    if (englishTerm != null) {
      return englishTerm;
    }

    // Check with common prefixes removed
    for (final prefix in _arabicPrefixes) {
      if (arabicTerm.startsWith(prefix) && arabicTerm.length > prefix.length) {
        final withoutPrefix = arabicTerm.substring(prefix.length);
        final match = _reverseMap[withoutPrefix];
        if (match != null) {
          return match;
        }
      }
    }

    return null;
  }

  /// Get all possible forms and synonyms for a term
  /// Returns a list of strings that would be acceptable matches
  List<String> getAllPossibleAnswers(String term, [String? category]) {
    if (!_isInitialized) init();

    final List<String> possibleAnswers = [];

    // Normalize input term
    term = term.trim().toLowerCase().replaceAll('_', ' ');

    // Add original term
    possibleAnswers.add(term);

    // Add synonyms if available
    final synonyms = _synonyms[term];
    if (synonyms != null) {
      possibleAnswers.addAll(synonyms);
    }

    // Add Arabic translation
    final translation = getArabicTranslation(term, category);
    if (translation != null) {
      possibleAnswers.add(translation.toLowerCase());

      // Add with "al" prefix for Arabic
      for (final prefix in _arabicPrefixes) {
        possibleAnswers.add('$prefix${translation.toLowerCase()}');
      }
    }

    return possibleAnswers;
  }

  /// Check if an answer matches any of the possible correct forms
  /// More flexible than direct equality check
  bool isCorrectAnswer(String userAnswer, String correctTerm,
      [String? category]) {
    if (!_isInitialized) init();

    userAnswer = userAnswer.trim().toLowerCase();

    // Get all possible acceptable answers
    final possibleAnswers = getAllPossibleAnswers(correctTerm, category);

    // Check for exact containment
    for (final answer in possibleAnswers) {
      if (userAnswer.contains(answer)) {
        return true;
      }
    }

    // If no match found, return false
    return false;
  }

  /// Get the list of available categories
  List<String> getCategories() {
    if (!_isInitialized) init();
    return _categoryMaps.keys.toList();
  }

  /// Get all translations for a category
  Map<String, String> getCategoryTranslations(String category) {
    if (!_isInitialized) init();
    return Map.from(_categoryMaps[category] ?? {});
  }
}
