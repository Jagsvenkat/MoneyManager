import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  int _currentTabIndex = 0;
  ThemeMode _themeMode = ThemeMode.dark;

  int get currentTabIndex => _currentTabIndex;
  ThemeMode get themeMode => _themeMode;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('theme_mode') ?? 'dark';
    _themeMode = val == 'light' ? ThemeMode.light : val == 'system' ? ThemeMode.system : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.system ? 'system' : 'dark');
    notifyListeners();
  }
}
