import 'package:flutter/material.dart';

class ColorProvider with ChangeNotifier {
  Color _primaryColor = Colors.blueAccent;

  Color get primaryColor => _primaryColor;

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }
}
