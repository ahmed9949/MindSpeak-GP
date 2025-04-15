import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';

class GameImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> getTwoLabeledImages(
      String category, String correctType) async {
    final folderRef = _storage.ref().child(category);
    final typesResult = await folderRef.listAll();
    final allTypes = typesResult.prefixes.map((ref) => ref.name).toList();

    final distractorTypes = List<String>.from(allTypes)..remove(correctType);
    if (distractorTypes.isEmpty) {
      throw Exception("No distractor type found.");
    }

    final distractorType =
        distractorTypes[Random().nextInt(distractorTypes.length)];

    final correctImage = await getRandomImage(category, correctType);
    final distractorImage = await getRandomImage(category, distractorType);

    if (correctImage == null || distractorImage == null) {
      throw Exception("Images missing in storage.");
    }

    final labeledImages = [
      {'url': correctImage, 'isCorrect': true},
      {'url': distractorImage, 'isCorrect': false}
    ]..shuffle();

    return labeledImages;
  }

  Future<String?> getRandomImage(String category, String type) async {
    final typeRef = _storage.ref().child('$category/$type');
    final result = await typeRef.listAll();

    if (result.items.isEmpty) return null;
    final randomRef = result.items[Random().nextInt(result.items.length)];
    return await randomRef.getDownloadURL();
  }

  /// ✅ NEW: Get all available types in a given category (Animals, Fruits, etc.)
  Future<List<String>> getTypesInCategory(String category) async {
    final categoryRef = _storage.ref().child(category);
    final result = await categoryRef.listAll();
    return result.prefixes.map((ref) => ref.name).toList();
  }
}
