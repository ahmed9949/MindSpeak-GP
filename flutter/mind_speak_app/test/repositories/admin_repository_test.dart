import 'package:flutter_test/flutter_test.dart';
import 'package:mind_speak_app/Repositories/AdminRepository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_repository_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  WriteBatch,
  User,
])
void main() {
  late AdminRepository adminRepository;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    adminRepository = AdminRepository(
      firestore: mockFirestore,
      auth: mockAuth,
    );
  });

  group('AdminRepository tests with extracted data', () {
    const therapistId = 'uqMSQvc5P9eEad4XwqBmmSXBcEM2';
    const userId = therapistId;

    final userData = {
      'email': 'mohamedhussam356@gmail.com',
      'username': 'Dr mohamed hussam',
      'password': '604bccbc...',
      'role': 'therapist',
      'phoneNumber': 1225666344,
      'status': false
    };

    final therapistData = {
      'userId': userId,
      'bio': 'I love engaging and playing with children',
      'nationalid': '12563487956321',
      'nationalproof': 'https://firebase-storage-url',
      'therapistimage': 'https://firebase-storage-url',
      'status': false
    };

    test('getPendingTherapistRequests returns pending therapists', () async {
      final therapistCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final therapistSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final therapistDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      final userCollection = MockCollectionReference<Map<String, dynamic>>();
      final userSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final userDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('therapist'))
          .thenReturn(therapistCollection);
      when(mockFirestore.collection('users')).thenReturn(userCollection);

      when(therapistCollection.where('status', isEqualTo: false))
          .thenReturn(therapistCollection);
      when(therapistCollection.get())
          .thenAnswer((_) async => therapistSnapshot);
      when(therapistSnapshot.docs).thenReturn([therapistDoc]);
      when(therapistDoc.id).thenReturn(therapistId);
      when(therapistDoc.data()).thenReturn(therapistData);

      when(therapistDoc['bio']).thenReturn(therapistData['bio']);
      when(therapistDoc['nationalid']).thenReturn(therapistData['nationalid']);
      when(therapistDoc['nationalproof'])
          .thenReturn(therapistData['nationalproof']);
      when(therapistDoc['therapistimage'])
          .thenReturn(therapistData['therapistimage']);
      when(therapistDoc['status']).thenReturn(therapistData['status']);

      when(userCollection.where(FieldPath.documentId, whereIn: [therapistId]))
          .thenReturn(userCollection);
      when(userCollection.get()).thenAnswer((_) async => userSnapshot);
      when(userSnapshot.docs).thenReturn([userDoc]);
      when(userDoc.id).thenReturn(userId);
      when(userDoc.data()).thenReturn(userData);

      final result = await adminRepository.getPendingTherapistRequests();

      expect(result.length, 1);
      expect(result[0]['user']?.email, 'mohamedhussam356@gmail.com');
      expect(result[0]['therapist']?.bio,
          'I love engaging and playing with children');

      print(
          '✅ getPendingTherapistRequests passed: Found ${result.length} pending therapist');
    });

    test('approveTherapist updates statuses', () async {
      final therapistCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final userCollection = MockCollectionReference<Map<String, dynamic>>();
      final therapistDocRef = MockDocumentReference<Map<String, dynamic>>();
      final userDocRef = MockDocumentReference<Map<String, dynamic>>();
      final therapistSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      final userSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      final batch = MockWriteBatch();

      when(mockFirestore.collection('therapist'))
          .thenReturn(therapistCollection);
      when(mockFirestore.collection('users')).thenReturn(userCollection);
      when(therapistCollection.doc(therapistId)).thenReturn(therapistDocRef);
      when(userCollection.doc(therapistId)).thenReturn(userDocRef);

      when(therapistDocRef.get()).thenAnswer((_) async => therapistSnapshot);
      when(userDocRef.get()).thenAnswer((_) async => userSnapshot);
      when(therapistSnapshot.exists).thenReturn(true);
      when(userSnapshot.exists).thenReturn(true);

      when(mockFirestore.batch()).thenReturn(batch);
      when(batch.update(therapistDocRef, {'status': true})).thenAnswer((_) {});
      when(batch.update(userDocRef, {'status': true})).thenAnswer((_) {});
      when(batch.commit()).thenAnswer((_) async {});

      final result = await adminRepository.approveTherapist(therapistId);

      expect(result, true);
      print(
          '✅ approveTherapist passed: Status updated for therapist $therapistId');
    });

    test('rejectTherapist deletes documents', () async {
      final therapistCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final userCollection = MockCollectionReference<Map<String, dynamic>>();
      final therapistDocRef = MockDocumentReference<Map<String, dynamic>>();
      final userDocRef = MockDocumentReference<Map<String, dynamic>>();
      final batch = MockWriteBatch();
      final mockUser = MockUser();

      when(mockFirestore.collection('therapist'))
          .thenReturn(therapistCollection);
      when(mockFirestore.collection('users')).thenReturn(userCollection);
      when(therapistCollection.doc(therapistId)).thenReturn(therapistDocRef);
      when(userCollection.doc(therapistId)).thenReturn(userDocRef);

      when(mockFirestore.batch()).thenReturn(batch);
      when(batch.delete(therapistDocRef)).thenAnswer((_) {});
      when(batch.delete(userDocRef)).thenAnswer((_) {});
      when(batch.commit()).thenAnswer((_) async {});

      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn(therapistId);
      when(mockUser.delete()).thenAnswer((_) async {});

      final result = await adminRepository.rejectTherapist(therapistId);

      expect(result, true);
      print('✅ rejectTherapist passed: Therapist $therapistId deleted');
    });

    test('getUsersCount returns correct count', () async {
      final usersCollection = MockCollectionReference<Map<String, dynamic>>();
      final snapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('users')).thenReturn(usersCollection);
      when(usersCollection.get()).thenAnswer((_) async => snapshot);
      when(snapshot.size).thenReturn(2);

      final count = await adminRepository.getUsersCount();
      expect(count, 2);
      print('✅ getUsersCount passed: Count = $count');
    });

    test('getTherapistsCount returns correct count', () async {
      final therapistsCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final snapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('therapist'))
          .thenReturn(therapistsCollection);
      when(therapistsCollection.get()).thenAnswer((_) async => snapshot);
      when(snapshot.size).thenReturn(2);

      final count = await adminRepository.getTherapistsCount();
      expect(count, 2);
      print('✅ getTherapistsCount passed: Count = $count');
    });
  });
}
