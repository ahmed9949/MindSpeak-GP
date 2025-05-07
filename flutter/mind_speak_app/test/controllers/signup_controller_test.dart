import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:mind_speak_app/Repositories/SignupRepository.dart';
import 'package:mind_speak_app/controllers/SignUpController.dart';
import 'signup_controller_test.mocks.dart';

@GenerateMocks([SignupRepository])
void main() {
  late SignUpController controller;
  late MockSignupRepository mockRepository;
  late GlobalKey<FormState> formKey;
  late BuildContext testContext;

  setUp(() {
    mockRepository = MockSignupRepository();
    formKey = GlobalKey<FormState>();
  });

  Future<void> pumpTestWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            testContext = context;
            return const SizedBox();
          }),
        ),
      ),
    );
  }

  group('validateImageUploads', () {
    testWidgets('returns false when childImage is null for parent role',
        (tester) async {
      await pumpTestWidget(tester);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'parent';
      controller.childImage = null;

      final result = controller.validateImageUploads();
      expect(result, isFalse);
      print(
          '✅ validateImageUploads (childImage null, parent role) passed: result=$result');
    });

    testWidgets('returns true when childImage is provided for parent role',
        (tester) async {
      await pumpTestWidget(tester);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'parent';
      controller.childImage = File('dummy.jpg');

      final result = controller.validateImageUploads();
      expect(result, isTrue);
      print(
          '✅ validateImageUploads (childImage provided, parent role) passed: result=$result');
    });

    testWidgets(
        'returns false when nationalProofImage or therapistImage is null for therapist role',
        (tester) async {
      await pumpTestWidget(tester);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'therapist';
      controller.nationalProofImage = null;
      controller.therapistImage = File('therapist.jpg');

      final result = controller.validateImageUploads();
      expect(result, isFalse);
      print(
          '✅ validateImageUploads (missing nationalProofImage, therapist role) passed: result=$result');
    });

    testWidgets(
        'returns true when both nationalProofImage and therapistImage are provided for therapist role',
        (tester) async {
      await pumpTestWidget(tester);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'therapist';
      controller.nationalProofImage = File('proof.jpg');
      controller.therapistImage = File('therapist.jpg');

      final result = controller.validateImageUploads();
      expect(result, isTrue);
      print(
          '✅ validateImageUploads (all images provided, therapist role) passed: result=$result');
    });
  });

  group('checkDuplicateEntries', () {
    testWidgets('returns false when parent phone number is already taken',
        (tester) async {
      await pumpTestWidget(tester);

      when(mockRepository.isParentPhoneNumberTaken(1028200287))
          .thenAnswer((_) async => true);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'parent';

      final result =
          await tester.runAsync(() => controller.checkDuplicateEntries());
      expect(result, isFalse);
      print(
          '✅ checkDuplicateEntries (parent phone taken) passed: result=$result');
    });

    testWidgets('returns true when parent phone number is NOT taken',
        (tester) async {
      await pumpTestWidget(tester);

      when(mockRepository.isParentPhoneNumberTaken(1028200287))
          .thenAnswer((_) async => false);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'parent';

      final result =
          await tester.runAsync(() => controller.checkDuplicateEntries());
      expect(result, isTrue);
      print(
          '✅ checkDuplicateEntries (parent phone not taken) passed: result=$result');
    });

    testWidgets('returns false when therapist phone number is already taken',
        (tester) async {
      await pumpTestWidget(tester);

      when(mockRepository.isTherapistPhoneNumberTaken(1028200287))
          .thenAnswer((_) async => true);
      when(mockRepository.isNationalIdTaken('30301260100631'))
          .thenAnswer((_) async => false);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'therapist';

      final result =
          await tester.runAsync(() => controller.checkDuplicateEntries());
      expect(result, isFalse);
      print(
          '✅ checkDuplicateEntries (therapist phone taken) passed: result=$result');
    });

    testWidgets('returns false when national ID is already taken',
        (tester) async {
      await pumpTestWidget(tester);

      when(mockRepository.isTherapistPhoneNumberTaken(1028200287))
          .thenAnswer((_) async => false);
      when(mockRepository.isNationalIdTaken('30301260100631'))
          .thenAnswer((_) async => true);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'therapist';

      final result =
          await tester.runAsync(() => controller.checkDuplicateEntries());
      expect(result, isFalse);
      print(
          '✅ checkDuplicateEntries (national ID taken) passed: result=$result');
    });

    testWidgets(
        'returns true when therapist phone and national ID are not taken',
        (tester) async {
      await pumpTestWidget(tester);

      when(mockRepository.isTherapistPhoneNumberTaken(1028200287))
          .thenAnswer((_) async => false);
      when(mockRepository.isNationalIdTaken('30301260100631'))
          .thenAnswer((_) async => false);

      controller = SignUpController(
        context: testContext,
        formKey: formKey,
        usernameController: TextEditingController(text: 'Ahmed Hossam'),
        emailController: TextEditingController(text: 'ahmed@example.com'),
        passwordController: TextEditingController(text: 'password123'),
        childNameController: TextEditingController(text: 'Child Name'),
        childAgeController: TextEditingController(text: '5'),
        childInterestController: TextEditingController(text: 'Cars'),
        nationalIdController: TextEditingController(text: '30301260100631'),
        bioController: TextEditingController(text: 'Experienced therapist'),
        parentPhoneNumberController: TextEditingController(text: '1028200287'),
        therapistPhoneNumberController:
            TextEditingController(text: '1028200287'),
        repository: mockRepository,
      );

      controller.role = 'therapist';

      final result =
          await tester.runAsync(() => controller.checkDuplicateEntries());
      expect(result, isTrue);
      print(
          '✅ checkDuplicateEntries (therapist phone and ID not taken) passed: result=$result');
    });
  });
}
