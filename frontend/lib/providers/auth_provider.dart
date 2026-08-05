import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _username;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get username => _username;

  /// Check if a valid, non-expired JWT token exists on app startup
  Future<void> checkAuthStatus() async {
    final token = await ApiService.getToken();
    
    if (token != null && token.isNotEmpty && !_isTokenExpired(token)) {
      _isAuthenticated = true;
      // 1. Try local storage first
      _username = await ApiService.getStoredUsername();
      // 2. Fallback to decoding token if missing
      _username ??= _parseUsernameFromToken(token);
    } else {
      // Token is missing or expired -> clear stored credentials
      if (token != null && token.isNotEmpty) {
        await ApiService.clearToken();
      }
      _isAuthenticated = false;
      _username = null;
    }
    
    notifyListeners();
  }

  /// Register a new user
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await ApiService.register(username, email, password);
      _username = username;
      await ApiService.saveUsername(username);
      _setLoading(false);
      // Auto-login after registration
      return await login(email, password);
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  /// Login existing user
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await ApiService.login(email, password);
      _isAuthenticated = true;

      // Extract username from login response or token claims
      String? extractedName;
      if (response['username'] != null) {
        extractedName = response['username'];
      } else {
        final token = await ApiService.getToken();
        if (token != null) {
          extractedName = _parseUsernameFromToken(token);
        }
      }

      // Fallback to email prefix if still missing
      extractedName ??= email.split('@')[0];

      _username = extractedName;
      await ApiService.saveUsername(extractedName);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Log out user and clear stored token
  Future<void> logout() async {
    await ApiService.clearToken();
    _isAuthenticated = false;
    _username = null;
    notifyListeners();
  }

  /// Check if the JWT token's 'exp' claim is past the current UTC time
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payloadMap = json.decode(resp);

      if (payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'] as int;
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
        return DateTime.now().toUtc().isAfter(expiryDate);
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Helper to decode JWT payload safely and extract display username
  String? _parseUsernameFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> payloadMap = json.decode(resp);

      // Check explicit username or name claims first
      final name = payloadMap['username'] ?? payloadMap['name'] ?? payloadMap['preferred_username'];
      if (name != null && name.toString().isNotEmpty) {
        return name.toString();
      }

      // Ignore purely numeric subject IDs (e.g., "1")
      final sub = payloadMap['sub']?.toString();
      if (sub != null && int.tryParse(sub) == null) {
        return sub;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}