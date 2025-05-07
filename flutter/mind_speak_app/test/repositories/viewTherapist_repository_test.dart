import 'package:flutter_test/flutter_test.dart';
import 'package:mind_speak_app/Repositories/ViewTherapistRepository.dart';
import 'package:mind_speak_app/models/Therapist.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'admin_repository_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentSnapshot,
])
void main() {
  late ViewTherapistRepository repository;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    repository = ViewTherapistRepository(firestore: mockFirestore);
  });

  const therapistId = 'uqMSQvc5P9eEad4XwqBmmSXBcEM2';
  const userId = therapistId;

  final therapistData = {
    'userId': userId,
    'bio': 'I love engaging and playing with children',
    'nationalid': '12563487956321',
    'nationalproof': 'https://firebase-storage-url',
    'therapistimage': 'https://firebase-storage-url',
    'status': false
  };

  final userData = {
    'email': 'mohamedhussam356@gmail.com',
    'username': 'Dr mohamed hussam',
    'password': '604bccbc...',
    'role': 'therapist',
    'phoneNumber': 1225666344,
    'status': false
  };

  test('fetchApprovedTherapists returns combined therapist and user data',
      () async {
    final therapistCollection = MockCollectionReference<Map<String, dynamic>>();
    final therapistQuery = MockQuery<Map<String, dynamic>>();
    final therapistSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
    final therapistDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

    final userCollection = MockCollectionReference<Map<String, dynamic>>();
    final userSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
    final userDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

    // Mock therapist fetch
    when(mockFirestore.collection('therapist')).thenReturn(therapistCollection);
    when(therapistCollection.where('status', isEqualTo: true))
        .thenReturn(therapistQuery);
    when(therapistQuery.get()).thenAnswer((_) async => therapistSnapshot);
    when(therapistSnapshot.docs).thenReturn([therapistDoc]);
    when(therapistDoc.id).thenReturn(therapistId);
    when(therapistDoc.data()).thenReturn(therapistData);

    // Mock user fetch
    when(mockFirestore.collection('users')).thenReturn(userCollection);
    when(userCollection.where(FieldPath.documentId, whereIn: [therapistId]))
        .thenReturn(userCollection);
    when(userCollection.get()).thenAnswer((_) async => userSnapshot);
    when(userSnapshot.docs).thenReturn([userDoc]);
    when(userDoc.id).thenReturn(userId);
    when(userDoc.data()).thenReturn(userData);

    final result = await repository.fetchApprovedTherapists();

    expect(result.length, 1);
    expect(result[0]['therapist'], isA<TherapistModel>());
    expect(result[0]['user'], isA<UserModel>());
    expect(result[0]['user']?.email, 'mohamedhussam356@gmail.com');
    expect(result[0]['therapist']?.bio,
        'I love engaging and playing with children');

    print(
        '✅ fetchApprovedTherapists passed: Found ${result.length} approved therapist');
  });

  test('fetchApprovedTherapists handles empty therapist list', () async {
    final therapistCollection = MockCollectionReference<Map<String, dynamic>>();
    final therapistQuery = MockQuery<Map<String, dynamic>>();
    final therapistSnapshot = MockQuerySnapshot<Map<String, dynamic>>();

    // Mock empty therapist list
    when(mockFirestore.collection('therapist')).thenReturn(therapistCollection);
    when(therapistCollection.where('status', isEqualTo: true))
        .thenReturn(therapistQuery);
    when(therapistQuery.get()).thenAnswer((_) async => therapistSnapshot);
    when(therapistSnapshot.docs).thenReturn([]);

    final result = await repository.fetchApprovedTherapists();

    expect(result.isEmpty, true);
    print('✅ fetchApprovedTherapists empty case passed');
  });

  test('fetchApprovedTherapists throws exception on Firestore error', () async {
    final therapistCollection = MockCollectionReference<Map<String, dynamic>>();
    final therapistQuery = MockQuery<Map<String, dynamic>>();

    when(mockFirestore.collection('therapist')).thenReturn(therapistCollection);
    when(therapistCollection.where('status', isEqualTo: true))
        .thenReturn(therapistQuery);
    when(therapistQuery.get()).thenThrow(Exception('Firestore error'));

    expect(() async => await repository.fetchApprovedTherapists(),
        throwsException);

    print('✅ fetchApprovedTherapists error case passed');
  });
}
