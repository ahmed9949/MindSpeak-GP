import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionProvider extends ChangeNotifier {
  String? _userId;
  String? _role;
  String? _childId;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessionDataList = [];
  List<Map<String, dynamic>> get sessionDataList => _sessionDataList;

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
      print('Fetching child ID for user: $_userId');

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('child')
          .where('userId', isEqualTo: _userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        // Assign childId from field or fallback to doc ID
        _childId = data.containsKey('childId') ? data['childId'] : doc.id;

        print('Child ID fetched: $_childId');

        // ✅ Now that _childId is ready, fetch session data
        await fetchSessionDataFromFirestore();
      } else {
        _childId = null;
        print('No child documents found for user $_userId');
      }
    } catch (e) {
      print('Error fetching child ID: $e');
      _childId = null;
    }

    notifyListeners(); // Safe to notify at the end
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

  Future<void> fetchSessionDataFromFirestore() async {
    if (_childId == null) {
      _sessionDataList = [];
      notifyListeners();
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('childId', isEqualTo: _childId)
          .orderBy('date', descending: true)
          .get();

      _sessionDataList = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      notifyListeners();
    } catch (e) {
      print("Error fetching sessions: $e");
      _sessionDataList = [];
      notifyListeners();
    }
  }

  int get thisWeekSessionCount {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return _sessionDataList.where((session) {
      final date = session['date']?.toDate();
      return date != null && date.isAfter(startOfWeek);
    }).length;
  }
}
