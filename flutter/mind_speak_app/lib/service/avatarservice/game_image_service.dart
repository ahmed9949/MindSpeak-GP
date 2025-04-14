import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';

class GameImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> getTwoRandomImages(String category, String type) async {
    final ListResult result = await _storage
        .ref('$category/$type') // e.g., 'Animals/Elephant'
        .listAll();

    final List<Reference> allImages = result.items;

    if (allImages.length < 2) {
      throw Exception('Not enough images to start the game.');
    }

    allImages.shuffle(Random());
    final List<String> urls = [];

    for (int i = 0; i < 2; i++) {
      final url = await allImages[i].getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}
