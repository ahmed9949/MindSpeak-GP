import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';

class GameImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> getLabeledImages({
    required String category,
    required String correctType,
    required int count,
  }) async {
    final folderRef = _storage.ref().child(category);
    final typesResult = await folderRef.listAll();
    final allTypes = typesResult.prefixes.map((ref) => ref.name).toList();

    final distractorTypes = List<String>.from(allTypes)..remove(correctType);
    distractorTypes.shuffle();

    final distractorPool = distractorTypes.take(count - 1).toList();

    final imageItems = <Map<String, dynamic>>[];

    final correctImage = await getRandomImage(category, correctType);
    if (correctImage != null) {
      imageItems.add({'url': correctImage, 'isCorrect': true});
    }

    for (final type in distractorPool) {
      final distractorImage = await getRandomImage(category, type);
      if (distractorImage != null) {
        imageItems.add({'url': distractorImage, 'isCorrect': false});
      }
    }

    imageItems.shuffle();
    return imageItems;
  }

  Future<String?> getRandomImage(String category, String type) async {
    final typeRef = _storage.ref().child('$category/$type');
    final result = await typeRef.listAll();

    if (result.items.isEmpty) return null;
    final randomRef = result.items[Random().nextInt(result.items.length)];
    return await randomRef.getDownloadURL();
  }

  Future<List<String>> getTypesInCategory(String category) async {
    final categoryRef = _storage.ref().child(category);
    final result = await categoryRef.listAll();
    return result.prefixes.map((ref) => ref.name).toList();
  }
}
