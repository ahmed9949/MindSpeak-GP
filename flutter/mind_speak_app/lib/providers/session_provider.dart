import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProvider extends ChangeNotifier {
  String? _userId;
  String? _role;
  bool _isLoggedIn = false;

  // Getters
  String? get userId => _userId;
  String? get role => _role;
  bool get isLoggedIn => _isLoggedIn;

  // Load session data from SharedPreferences
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _role = prefs.getString('role');
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    notifyListeners();
  }

  // Save session data to SharedPreferences
  Future<void> saveSession(String userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setBool('isLoggedIn', true);

    _userId = userId;
    _role = role;
    _isLoggedIn = true;
    notifyListeners();
  }

  // Clear session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userId = null;
    _role = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
