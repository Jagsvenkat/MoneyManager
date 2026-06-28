import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthService? _authService;
  bool _isAuthenticated = false;
  String? _currentUserId;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthService? get authService => _authService;

  Future<void> initialize() async {
    _authService = AuthService();
    await _authService!.initialize();
    notifyListeners();
  }

  Future<bool> register(String email, String password) async {
    if (_authService == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService!.register(username: email, password: password);
      _isAuthenticated = true;
      _currentUserId = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    if (_authService == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService!.login(username: email, password: password);
      _isAuthenticated = true;
      _currentUserId = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService?.logout();
    _isAuthenticated = false;
    _currentUserId = null;
    _error = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
