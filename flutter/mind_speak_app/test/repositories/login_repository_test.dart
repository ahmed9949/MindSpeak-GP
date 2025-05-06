import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mind_speak_app/repositories/LoginRepository.dart';
import 'package:mind_speak_app/models/User.dart';
import 'package:mind_speak_app/models/Child.dart';
import 'package:mind_speak_app/models/Therapist.dart';

import 'login_repository_test.mocks.dart';

const testUsername = 'Ahmed Hossam';
const testEmail = 'ahmedhossam26103@gmail.com';
const testPassword = 'password123';
const testChildName = 'Tata';
const testChildAge = 5;
const testChildInterest = 'Cars';
const testNationalId = '30301260100631';
const testBio = 'Experienced therapist';
const testParentPhone = 1028200287;
const testTherapistPhone = 1028200286;

@GenerateMocks([
  FirebaseFirestore,
  auth.FirebaseAuth,
  GoogleSignIn,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  QueryDocumentSnapshot,
  auth.UserCredential,
  auth.User,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
])
void main() {
  late LoginRepository repository;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();

    repository = LoginRepository(
      firestore: mockFirestore,
      auth: mockAuth,
      googleSignIn: mockGoogleSignIn,
    );
  });

  group('hashPassword', () {
    test('returns SHA256 hash', () {
      final result = repository.hashPassword(testPassword);
      print('🔑 Hash result: $result');
      expect(result.length, 64);
      print('✅ hashPassword passed');
    });
  });

  group('authenticateUser', () {
    test('returns UserModel when authentication succeeds', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

      when(mockAuth.signInWithEmailAndPassword(
              email: testEmail, password: testPassword))
          .thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user123');
      when(mockUser.emailVerified).thenReturn(true);

      when(mockFirestore.collection('users')).thenReturn(
          mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.doc('user123')).thenReturn(mockDocRef);
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({
        'email': testEmail,
        'username': testUsername,
        'role': 'parent',
        'phoneNumber': testParentPhone,
        'password': testPassword,
      });
      when(mockDocSnapshot.id).thenReturn('user123');

      final result = await repository.authenticateUser(testEmail, testPassword);

      print('🎯 authenticateUser result:');
      print('  email: ${result.email}');
      print('  username: ${result.username}');
      print('  role: ${result.role}');
      print('  phoneNumber: ${result.phoneNumber}');

      expect(result, isA<UserModel>());
      expect(result.email, testEmail);
      expect(result.username, testUsername);
      expect(result.phoneNumber, testParentPhone);
      print('✅ authenticateUser success');
    });
  });

  group('signInWithGoogle', () {
    test('returns UserModel when google sign in succeeds', () async {
      final mockGoogleUser = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      final mockUserCredential = MockUserCredential();
      final mockAuthUser = MockUser();
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();

      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
      when(mockGoogleUser.authentication)
          .thenAnswer((_) async => mockGoogleAuth);
      when(mockGoogleAuth.accessToken).thenReturn('token');
      when(mockGoogleAuth.idToken).thenReturn('idtoken');

      when(mockAuth.signInWithCredential(any))
          .thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockAuthUser);
      when(mockAuthUser.uid).thenReturn('googleUser123');

      when(mockFirestore.collection('users')).thenReturn(
          mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.doc('googleUser123')).thenReturn(mockDocRef);
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({
        'email': testEmail,
        'username': testUsername,
        'role': 'Parent',
        'phoneNumber': testParentPhone,
      });
      when(mockDocSnapshot.id).thenReturn('googleUser123');

      final result = await repository.signInWithGoogle();

      print('🎯 signInWithGoogle result:');
      print('  email: ${result.email}');
      print('  username: ${result.username}');
      print('  role: ${result.role}');
      print('  phoneNumber: ${result.phoneNumber}');

      expect(result, isA<UserModel>());
      expect(result.email, testEmail);
      expect(result.username, testUsername);
      print('✅ signInWithGoogle success');
    });
  });

  group('fetchChildData', () {
    test('returns ChildModel if found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockQueryDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('child')).thenReturn(
          mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.where('userId', isEqualTo: 'user123'))
          .thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
      when(mockQueryDoc.data()).thenReturn({
        'name': testChildName,
        'age': testChildAge,
        'childInterest': testChildInterest,
      });
      when(mockQueryDoc.id).thenReturn('childDocId');

      final result = await repository.fetchChildData('user123');

      print('🎯 fetchChildData result:');
      print('  name: ${result.name}');
      print('  age: ${result.age}');
      print('  interest: ${result.childInterest}');

      expect(result.name, testChildName);
      expect(result.childInterest, testChildInterest);
    });
  });

  group('fetchCarsFormStatus', () {
    test('returns CarsFormModel if found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockQueryDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('Cars')).thenReturn(
          mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.where('childId', isEqualTo: 'child123'))
          .thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
      when(mockQueryDoc.data()).thenReturn({
        'status': true,
      });
      when(mockQueryDoc.id).thenReturn('carsDocId');

      final result = await repository.fetchCarsFormStatus('child123');

      print('🎯 fetchCarsFormStatus result:');
      print('  status: ${result?.status}');

      expect(result, isNotNull);
      expect(result!.status, true);
      print('✅ fetchCarsFormStatus success');
    });
  });

  group('fetchTherapistInfo', () {
    test('returns TherapistModel if found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockQueryDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('therapist')).thenReturn(
          mockCollection as CollectionReference<Map<String, dynamic>>);
      when(mockCollection.where('userId', isEqualTo: 'user123'))
          .thenReturn(mockCollection);
      when(mockCollection.limit(1)).thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
      when(mockQueryDoc.data()).thenReturn({
        'userId': 'user123',
        'bio': testBio,
        'nationalid': testNationalId,
        'nationalproof': 'proof.jpg',
        'therapistimage': 'therapist.jpg',
        'status': true,
      });
      when(mockQueryDoc.id).thenReturn('therapistDocId');

      final result = await repository.fetchTherapistInfo('user123');

      print('🎯 fetchTherapistInfo result:');
      print('  bio: ${result.bio}');
      print('  nationalId: ${result.nationalId}');
      print('  nationalProof: ${result.nationalProof}');
      print('  therapistImage: ${result.therapistImage}');
      print('  status: ${result.status}');

      expect(result, isA<TherapistModel>());
      expect(result.bio, testBio);
      expect(result.nationalId, testNationalId);
      expect(result.nationalProof, 'proof.jpg');
      expect(result.therapistImage, 'therapist.jpg');
      expect(result.status, true);
      print('✅ fetchTherapistInfo success');
    });
  });

  group('authenticateUser - invalid cases', () {
    test('throws Exception when wrong password provided', () async {
      when(mockAuth.signInWithEmailAndPassword(
              email: testEmail, password: testPassword))
          .thenThrow(auth.FirebaseAuthException(code: 'wrong-password'));

      try {
        await repository.authenticateUser(testEmail, testPassword);
      } catch (e) {
        print('❌ authenticateUser failed: $e');
        expect(e, isA<Exception>());
        expect(e.toString(),
            contains('Incorrect email or password. Please try again.'));
        print('✅ authenticateUser invalid password test passed');
      }
    });

    test('throws Exception when user email not verified', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();

      when(mockAuth.signInWithEmailAndPassword(
              email: testEmail, password: testPassword))
          .thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(false);

      try {
        await repository.authenticateUser(testEmail, testPassword);
      } catch (e) {
        print('❌ authenticateUser email not verified: $e');
        expect(e, isA<Exception>());
        expect(e.toString(), contains('verify your email'));
        print('✅ authenticateUser email verification test passed');
      }
    });

    test('throws Exception when user document does not exist', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      final mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

      when(mockAuth.signInWithEmailAndPassword(
              email: testEmail, password: testPassword))
          .thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user123');
      when(mockUser.emailVerified).thenReturn(true);

      when(mockFirestore.collection('users')).thenReturn(mockCollection);
      when(mockCollection.doc('user123')).thenReturn(mockDocRef);
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(false);

      try {
        await repository.authenticateUser(testEmail, testPassword);
      } catch (e) {
        print('❌ authenticateUser user doc missing: $e');
        expect(e, isA<Exception>());
        expect(e.toString(), contains('rejected by the admin'));
        print('✅ authenticateUser missing doc test passed');
      }
    });
  });

  group('fetchChildData - invalid case', () {
    test('throws Exception when no child found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('child')).thenReturn(mockCollection);
      when(mockCollection.where('userId', isEqualTo: 'user123'))
          .thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([]);

      try {
        await repository.fetchChildData('user123');
      } catch (e) {
        print('❌ fetchChildData no child found: $e');
        expect(e, isA<Exception>());
        expect(e.toString(), contains('No child associated'));
        print('✅ fetchChildData no child found test passed');
      }
    });
  });

  group('fetchCarsFormStatus - invalid case', () {
    test('returns null when no Cars form found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('Cars')).thenReturn(mockCollection);
      when(mockCollection.where('childId', isEqualTo: 'child123'))
          .thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([]);

      final result = await repository.fetchCarsFormStatus('child123');

      print('🎯 fetchCarsFormStatus no form found result: $result');
      expect(result, isNull);
      print('✅ fetchCarsFormStatus no form found test passed');
    });
  });

  group('fetchTherapistInfo - invalid case', () {
    test('throws Exception when no therapist found', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('therapist')).thenReturn(mockCollection);
      when(mockCollection.where('userId', isEqualTo: 'user123'))
          .thenReturn(mockCollection);
      when(mockCollection.limit(1)).thenReturn(mockCollection);
      when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([]);

      try {
        await repository.fetchTherapistInfo('user123');
      } catch (e) {
        print('❌ fetchTherapistInfo no therapist found: $e');
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Therapist information not found'));
        print('✅ fetchTherapistInfo no therapist found test passed');
      }
    });
  });
}
