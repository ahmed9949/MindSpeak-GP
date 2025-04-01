// import 'package:mind_speak_app/models/User.dart';

// class AdminModel extends UserModel {
//   AdminModel({
//     required String userId,
//     required String email,
//     required String username,
//     required String password,
//     required int phoneNumber,
//     bool biometricEnabled = false,
//   }) : super(
//           userId: userId,
//           email: email,
//           username: username,
//           role: 'admin',
//           password: password,
//           phoneNumber: phoneNumber,
//           biometricEnabled: biometricEnabled,
//         );

//   factory AdminModel.fromFirestore(Map<String, dynamic> data, String id) {
//     return AdminModel(
//       userId: id,
//       email: data['email'] ?? '',
//       username: data['username'] ?? '',
//       password: data['password'] ?? '',
//       phoneNumber: data['phoneNumber'] ?? 0,
//       biometricEnabled: data['biometricEnabled'] ?? false,
//     );
//   }

//   @override
//   Map<String, dynamic> toFirestore() {
//     return {
//       'email': email,
//       'username': username,
//       'password': password,
//       'phoneNumber': phoneNumber,
//       'role': role,
//       'biometricEnabled': biometricEnabled,
//     };
//   }

//   AdminModel copyWith({
//     String? userId,
//     String? email,
//     String? username,
//     String? password,
//     int? phoneNumber,
//     bool? biometricEnabled,
//   }) {
//     return AdminModel(
//       userId: userId ?? this.userId,
//       email: email ?? this.email,
//       username: username ?? this.username,
//       password: password ?? this.password,
//       phoneNumber: phoneNumber ?? this.phoneNumber,
//       biometricEnabled: biometricEnabled ?? this.biometricEnabled,
//     );
//   }
// }
