import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';

class GameImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> getLabeledImages({
    required String category,
    required String correctType,
    required int count,
  }) async {
    print(
        '🔍 Getting labeled images for category="$category", correctType="$correctType", count=$count');

    final folderRef = _storage.ref().child(category);
    final typesResult = await folderRef.listAll();
    final allTypes = typesResult.prefixes.map((ref) => ref.name).toList();

    print('📁 Found ${allTypes.length} types in "$category": $allTypes');

    // Match correctType ignoring case
    final match = allTypes.firstWhere(
      (type) => type.toLowerCase() == correctType.toLowerCase(),
      orElse: () => '',
    );

    if (match.isEmpty) {
      print(
          '❌ Correct type "$correctType" not found (case-insensitive) in Firebase Storage category "$category".');
      return [];
    }

    final correctedType = match;
    final distractorTypes = List<String>.from(allTypes)..remove(correctedType);
    distractorTypes.shuffle();

    final distractorPool = distractorTypes.take(count - 1).toList();
    final imageItems = <Map<String, dynamic>>[];

    // Prepare futures for all image fetches
    final futures = <Future<Map<String, dynamic>?>>[];

    // Correct image
    futures.add(_getImageItem(category, correctedType, true));

    // Distractors
    for (final type in distractorPool) {
      futures.add(_getImageItem(category, type, false));
    }

    final results = await Future.wait(futures);
    imageItems.addAll(results.whereType<Map<String, dynamic>>());
    imageItems.shuffle();

    print('✅ Loaded ${imageItems.length} image items for the game.');
    return imageItems;
  }

  Future<Map<String, dynamic>?> _getImageItem(
      String category, String type, bool isCorrect) async {
    try {
      final typeRef = _storage.ref().child('$category/$type');
      final result = await typeRef.listAll();

      if (result.items.isEmpty) {
        print('⚠️ No images found for "$type" in "$category"');
        return null;
      }

      final randomRef = result.items[Random().nextInt(result.items.length)];
      final url = await randomRef.getDownloadURL();
      print(
          '📸 Loaded image for "$type" (${isCorrect ? "correct" : "distractor"}): $url');

      return {'url': url, 'isCorrect': isCorrect};
    } catch (e) {
      print('❌ Failed to fetch image for "$type" in "$category": $e');
      return null;
    }
  }

  Future<String?> getRandomImage(String category, String type) async {
    try {
      final typeRef = _storage.ref().child('$category/$type');
      final result = await typeRef.listAll();

      if (result.items.isEmpty) {
        print('⚠️ No images found for "$type" in "$category"');
        return null;
      }

      final randomRef = result.items[Random().nextInt(result.items.length)];
      final url = await randomRef.getDownloadURL();
      print('🔗 Random image URL for "$type": $url');
      return url;
    } catch (e) {
      print('❌ Error in getRandomImage(): $e');
      return null;
    }
  }

  Future<List<String>> getTypesInCategory(String category) async {
    try {
      final categoryRef = _storage.ref().child(category);
      final result = await categoryRef.listAll();
      final types = result.prefixes.map((ref) => ref.name).toList();
      print('📂 Types in category "$category": $types');
      return types;
    } catch (e) {
      print('❌ Error listing types in "$category": $e');
      return [];
    }
  }
}
