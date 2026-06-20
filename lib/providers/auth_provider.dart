import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';

/// Manages authentication state
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isAuthenticated = false;
  String? _currentUserId;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Register a new user
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(email, password);
      _isAuthenticated = true;
      _currentUserId = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login an existing user
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      _isAuthenticated = true;
      _currentUserId = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    _isAuthenticated = false;
    _currentUserId = null;
    _error = null;
    notifyListeners();
  }

  /// Check if user is authenticated on app start
  Future<void> checkAuthStatus() async {
    // TODO: Implement session persistence from secure storage
    // For now, assume not authenticated unless login is called
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
