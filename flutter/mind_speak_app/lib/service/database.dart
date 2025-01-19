import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMethods {
  // hena 3ashn inject el function fel 7eta ely 3ayzha fel project dependencies injection
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future addUser(String userId, Map<String, dynamic> userInfoMap) {
    return FirebaseFirestore.instance
        .collection("User")
        .doc(userId)
        .set(userInfoMap);
  }


  // hena function 3ashn a count number of users fel system
  Future<int> getUsersCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('user').get();
      return snapshot.size;
    } catch (e) {
      throw Exception('Failed to fetch users count $e');
    }
  }

  // hena function 3ashn a count number of therapists fel system
  Future<int> getTherapistsCount() async {
    try{
      QuerySnapshot snapshot = await _firestore.collection('therapist').get();
      return snapshot.size;
    }

    catch (e) {
      throw Exception('Failed to fetch therapists count $e');
    }
  }
}
