import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String _userName = 'Student';

  bool get isDarkMode => _isDarkMode;
  String get userName => _userName;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void updateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      _userName = trimmed;
    }
    notifyListeners();
  }
}