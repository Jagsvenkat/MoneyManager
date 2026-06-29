import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';

/// Maps AuthService exceptions to user-safe messages
String _safeErrorMessage(Object e) {
  final msg = e.toString();
  if (msg.contains('User not found')) return 'Account not found. Please register.';
  if (msg.contains('Invalid password')) return 'Incorrect password. Try again.';
  if (msg.contains('Password must be at least')) return 'Password must be at least 12 characters.';
  if (msg.contains('No backup UMK')) return 'Account data missing. Please re-register.';
  return 'Something went wrong. Please try again.';
}

class AuthProvider extends ChangeNotifier {
  AuthService? _authService;
  bool _isAuthenticated = false;
  String? _currentUserId;
  bool _isLoading = false;
  String? _error;
  String? _rawError;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get rawError => _rawError;
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
      _error = _safeErrorMessage(e);
      _rawError = e.toString();
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
      _error = _safeErrorMessage(e);
      _rawError = e.toString();
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

  Future<void> deleteAccount() async {
    if (_authService == null) return;
    await _authService!.deleteAccount();
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
