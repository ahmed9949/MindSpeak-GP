class UserModel {
  final String userId;
  final String email;
  final String username;
  final String role;
  final bool biometricEnabled;

  UserModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.role,
    this.biometricEnabled = false,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      userId: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      role: data['role'] ?? '',
      biometricEnabled: data['biometricEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'role': role,
      'biometricEnabled': biometricEnabled,
    };
  }
}
