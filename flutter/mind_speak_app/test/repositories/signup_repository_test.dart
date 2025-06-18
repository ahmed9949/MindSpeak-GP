import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_speak_app/Repositories/SignupRepository.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/models/Therapist.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot,
  CollectionReference<Map<String, dynamic>>,
  Query<Map<String, dynamic>>,
  QuerySnapshot<Map<String, dynamic>>,
  QueryDocumentSnapshot<Map<String, dynamic>>,
  DocumentReference<Map<String, dynamic>>,
  UserCredential
])
import 'signup_repository_test.mocks.dart';

void main() {
  late SignupRepository repository;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseStorage mockStorage;
  late MockReference mockReference;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockTaskSnapshot;
  late MockCollectionReference<Map<String, dynamic>> mockCollectionReference;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>>
      mockQueryDocumentSnapshot;
  late MockDocumentReference<Map<String, dynamic>> mockDocumentReference;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    mockReference = MockReference();
    mockUploadTask = MockUploadTask();
    mockTaskSnapshot = MockTaskSnapshot();
    mockCollectionReference = MockCollectionReference<Map<String, dynamic>>();
    mockQuery = MockQuery<Map<String, dynamic>>();
    mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
    mockQueryDocumentSnapshot =
        MockQueryDocumentSnapshot<Map<String, dynamic>>();
    mockDocumentReference = MockDocumentReference<Map<String, dynamic>>();

    repository = SignupRepository(
      auth: mockAuth,
      firestore: mockFirestore,
      storage: mockStorage,
    );
  });

  group('SignupRepository Tests', () {
    test('generateChildId returns a valid UUID', () {
      final childId = repository.generateChildId();
      print('Generated Child ID: $childId');
      expect(childId, isNotEmpty);
    });

    test('hashPassword returns a valid SHA-256 hash', () {
      final password = 'testPassword123';
      final hashedPassword = repository.hashPassword(password);
      print('Original password: $password');
      print('Hashed password: $hashedPassword');
      expect(hashedPassword.length, equals(64));
    });

    /// ✅ PASS: username exists
    test('isValueTaken returns true when username exists', () async {
      when(mockQueryDocumentSnapshot.data())
          .thenReturn({'username': 'Ahmed Hossam'});
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocumentSnapshot]);
      when(mockFirestore.collection(any)).thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('username',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result =
          await repository.isValueTaken('users', 'username', 'Ahmed Hossam');
      print('Username exists? $result');
      expect(result, isTrue);
    });

    /// ❌ FAIL: username not found
    test('isValueTaken returns false when username does not exist', () async {
      when(mockQuerySnapshot.docs).thenReturn([]);
      when(mockFirestore.collection(any)).thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('username',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result =
          await repository.isValueTaken('users', 'username', 'NotExist');
      print('Username exists? $result');
      expect(result, isFalse);
    });

    test('createFirebaseUser creates user successfully', () async {
      final user = UserModel(
        userId: 'test123',
        username: 'Ahmed Hossam',
        email: 'ahmed@example.com',
        password: 'password123',
        role: 'parent',
        phoneNumber: 1028200287,
      );
      final mockUserCredential = MockUserCredential();
      when(mockAuth.createUserWithEmailAndPassword(
              email: user.email, password: user.password))
          .thenAnswer((_) async => mockUserCredential);

      final result = await repository.createFirebaseUser(user);
      print('Created user: $result');
      expect(result, equals(mockUserCredential));
    });

    test('saveUserDetails saves user data to Firestore', () async {
      when(mockFirestore.collection('users'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.doc('test123'))
          .thenReturn(mockDocumentReference);
      when(mockDocumentReference.set(any)).thenAnswer((_) async => null);

      final user = UserModel(
        userId: 'test123',
        username: 'Ahmed Hossam',
        email: 'ahmed@example.com',
        password: 'password123',
        role: 'parent',
        phoneNumber: 1028200287,
      );

      await repository.saveUserDetails(user);
      print('Saved user details for ${user.username}');
      verify(mockDocumentReference.set(any)).called(1);
    });

    /// ✅ PASS: parent phone exists
    test('isParentPhoneNumberTaken returns true when phone exists', () async {
      when(mockQueryDocumentSnapshot.data())
          .thenReturn({'phoneNumber': 1028200287});
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocumentSnapshot]);
      when(mockFirestore.collection('parent'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('phoneNumber',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isParentPhoneNumberTaken(1028200287);
      print('Parent phone exists? $result');
      expect(result, isTrue);
    });

    /// ❌ FAIL: parent phone not found
    test('isParentPhoneNumberTaken returns false when phone does not exist',
        () async {
      when(mockQuerySnapshot.docs).thenReturn([]);
      when(mockFirestore.collection('parent'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('phoneNumber',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isParentPhoneNumberTaken(999999999);
      print('Parent phone exists? $result');
      expect(result, isFalse);
    });

    /// ✅ PASS: therapist phone exists
    test('isTherapistPhoneNumberTaken returns true when therapist phone exists',
        () async {
      when(mockQueryDocumentSnapshot.data())
          .thenReturn({'therapistNumber': 1028200287});
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocumentSnapshot]);
      when(mockFirestore.collection('therapist'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('therapistNumber',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isTherapistPhoneNumberTaken(1028200287);
      print('Therapist phone exists? $result');
      expect(result, isTrue);
    });

    /// ❌ FAIL: therapist phone not found
    test(
        'isTherapistPhoneNumberTaken returns false when therapist phone does not exist',
        () async {
      when(mockQuerySnapshot.docs).thenReturn([]);
      when(mockFirestore.collection('therapist'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('therapistNumber',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isTherapistPhoneNumberTaken(999999999);
      print('Therapist phone exists? $result');
      expect(result, isFalse);
    });

    /// ✅ PASS: national ID exists
    test('isNationalIdTaken returns true when national ID exists', () async {
      when(mockQueryDocumentSnapshot.data())
          .thenReturn({'nationalid': '30301260100631'});
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocumentSnapshot]);
      when(mockFirestore.collection('therapist'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('nationalid',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isNationalIdTaken('30301260100631');
      print('National ID exists? $result');
      expect(result, isTrue);
    });

    /// ❌ FAIL: national ID not found
    test('isNationalIdTaken returns false when national ID does not exist',
        () async {
      when(mockQuerySnapshot.docs).thenReturn([]);
      when(mockFirestore.collection('therapist'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.where('nationalid',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

      final result = await repository.isNationalIdTaken('99999999999999');
      print('National ID exists? $result');
      expect(result, isFalse);
    });

    /// ✅ NEW: saveTherapistDetails saves therapist to Firestore
    test('saveTherapistDetails saves therapist data to Firestore', () async {
      when(mockFirestore.collection('therapist'))
          .thenReturn(mockCollectionReference);
      when(mockCollectionReference.doc('therapist123'))
          .thenReturn(mockDocumentReference);
      when(mockDocumentReference.set(any)).thenAnswer((_) async => null);

      final therapist = TherapistModel(
        therapistId: 'therapist123',
        userId: 'user123',
        bio: 'Experienced therapist in child autism treatment',
        nationalId: '30301260100631',
        nationalProof: 'proof_image_url.jpg',
        therapistImage: 'therapist_image_url.jpg',
        status: false,
      );

      await repository.saveTherapistDetails(therapist);
      print('Saved therapist details for ID ${therapist.therapistId}');
      verify(mockDocumentReference.set(any)).called(1);
    });
  });
}
