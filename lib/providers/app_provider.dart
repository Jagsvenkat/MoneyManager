import 'package:flutter/material.dart';

/// Manages general application state
class AppProvider extends ChangeNotifier {
  int _selectedTabIndex = 0;
  bool _isDarkMode = true;

  int get selectedTabIndex => _selectedTabIndex;
  bool get isDarkMode => _isDarkMode;

  /// Set the selected tab index
  void setSelectedTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  /// Toggle theme
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Set theme explicitly
  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}
