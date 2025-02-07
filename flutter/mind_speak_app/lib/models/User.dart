class UserModel {
  final String userId;
  final String email;
  final String username;
  final String role;
  final String password;
  final bool biometricEnabled;

  UserModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.role,
    required this.password,
    this.biometricEnabled = false,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      userId: id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      role: data['role'] ?? '',
      password: data['password'] ?? '',
      biometricEnabled: data['biometricEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'username': username,
      'role': role,
      'password': password,
      'biometricEnabled': biometricEnabled,
    };
  }

  UserModel copyWith({
    String? userId,
    String? email,
    String? username,
    String? role,
    String? password,
    bool? biometricEnabled,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      password: password ?? this.password,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}
