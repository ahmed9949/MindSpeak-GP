import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionProvider extends ChangeNotifier {
  String? _userId;
  String? _role;
  String? _childId;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  // Getters
  String? get userId => _userId;
  String? get role => _role;
  String? get childId => _childId;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Constructor to immediately load session
  SessionProvider() {
    loadSession();
  }

  // Load session data from SharedPreferences
  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      _role = prefs.getString('role');
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (_userId != null) {
        await fetchChildId(); // Fetch child ID for the current user
      }
    } catch (e) {
      print('Error loading session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save session data to SharedPreferences
  Future<void> saveSession(String userId, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('role', role);
      await prefs.setBool('isLoggedIn', true);

      _userId = userId;
      _role = role;
      _isLoggedIn = true;

      await fetchChildId(); // Fetch child ID when a session is created
    } catch (e) {
      print('Error saving session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear session data
  Future<void> clearSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _userId = null;
      _role = null;
      _childId = null;
      _isLoggedIn = false;
    } catch (e) {
      print('Error clearing session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch the child ID for the current user
  Future<void> fetchChildId() async {
    if (_userId == null) {
      _childId = null;
      notifyListeners();
      return;
    }

    try {
      print('Fetching child ID for user: $_userId'); // Debug log

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: _userId)
          .limit(1) // Only get the first matching document
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Try both approaches to find the childId
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        // Check if 'childId' exists as a field in the document
        if (data.containsKey('childId')) {
          _childId = data['childId'];
        } else {
          // Otherwise use the document ID as the childId
          _childId = doc.id;
        }

        print('Child ID fetched: $_childId'); // Debug log
      } else {
        _childId = null;
        print('No child documents found for user $_userId'); // Debug log
      }
    } catch (e) {
      print('Error fetching child ID: $e');
      _childId = null;
    }

    notifyListeners(); // Notify listeners of the change
  }

  // Method to add a new child and get its ID
  Future<String?> addChild(Map<String, dynamic> childData) async {
    if (_userId == null) return null;

    try {
      // Add userId to the child data
      childData['userId'] = _userId;

      // Add the document to Firestore
      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('child').add(childData);

      // Set the childId
      _childId = docRef.id;
      notifyListeners();

      return _childId;
    } catch (e) {
      print('Error adding child: $e');
      return null;
    }
  }
}
