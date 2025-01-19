import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionProvider extends ChangeNotifier {
  String? _userId;
  String? _role;
  String? _childId;
  bool _isLoggedIn = false;

  // Getters
  String? get userId => _userId;
  String? get role => _role;
  String? get childId => _childId;
  bool get isLoggedIn => _isLoggedIn;

  // Load session data from SharedPreferences
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _role = prefs.getString('role');
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (_userId != null) {
      await fetchChildId(); // Fetch child ID for the current user
    }
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

    await fetchChildId(); // Fetch child ID when a session is created
    notifyListeners();
  }

  // Clear session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userId = null;
    _role = null;
    _childId = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // Fetch the child ID for the current user
  Future<void> fetchChildId() async {
    if (_userId == null) return; // Ensure the userId is available

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: _userId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _childId = querySnapshot.docs.first['childId'];
      } else {
        _childId = null; // No child ID found for the user
      }
    } catch (e) {
      print('Error fetching child ID: $e');
      _childId = null; // Handle errors gracefully
    }

    notifyListeners(); // Notify listeners of the change
  }
}
