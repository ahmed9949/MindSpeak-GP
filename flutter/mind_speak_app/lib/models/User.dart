class UserModel {
  final String userId;
  final String email;
  final String username;
  final String role;
  final String password;
  final int phoneNumber;
  final bool biometricEnabled;

  UserModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.role,
    required this.password,
    required this.phoneNumber,
    this.biometricEnabled = false,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      userId: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      role: data['role'] ?? '',
      password: data['password'] ?? '',
      phoneNumber: data['phoneNumber'] ?? 0,
      biometricEnabled: data['biometricEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'password': password,
      'role': role,
      'phoneNumber': phoneNumber,
      'biometricEnabled': biometricEnabled,
      'userid': userId,
    };
  }
}
