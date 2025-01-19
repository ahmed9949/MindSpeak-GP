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


 

  


//De func 3ashan ageb kol el children ba3d keda kol ther hayb2a leh el children bto3oh b el id bta3o 
  Future<List<Map<String, dynamic>>> getAllChildren() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('child').get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Failed to fetch children: $e');
    }
  }



//De func 3ashan ageb el reports bat3t el child b el id bta3o
  Future<List<Map<String, dynamic>>> fetchReportsForChild(String childId) async {
  try {
    QuerySnapshot snapshot = await _firestore
        .collection('reports')
        .where('childId', isEqualTo: childId)
        .get();

    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  } catch (e) {
    throw Exception('Failed to fetch reports for child: $e');
  }
}

}
