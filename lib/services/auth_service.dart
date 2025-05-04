import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService extends ChangeNotifier {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Constants
  static const String _authTokenKey = 'supabase_auth_token';
  static const String _userDataKey = 'user_data';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Secure storage for sensitive data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Internal state
  bool _isInitialized = false;
  bool _isLoading = false;
  User? _currentUser;
  String? _error;
  late StreamSubscription<AuthState> _authSubscription;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  User? get currentUser => _currentUser;
  String? get error => _error;

  // Initialize the auth service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);

      // Listen to auth state changes
      _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            _currentUser = session?.user;
            _saveUserDataToSecureStorage();
            break;
          case AuthChangeEvent.signedOut:
            _currentUser = null;
            _clearUserDataFromSecureStorage();
            break;
          case AuthChangeEvent.userUpdated:
            _currentUser = session?.user;
            _saveUserDataToSecureStorage();
            break;
          case AuthChangeEvent.passwordRecovery:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userDeleted:
          case AuthChangeEvent.mfaChallengeVerified:
          default:
            break;
        }
        notifyListeners();
      });

      // Check for existing session
      final currentSession = supabase.auth.currentSession;
      if (currentSession != null) {
        _currentUser = currentSession.user;
        debugPrint('User already signed in: ${_currentUser?.email}');
      }

      _isInitialized = true;
      _setLoading(false);
    } catch (e) {
      _setError('Error initializing auth service: $e');
      _setLoading(false);
    }
  }

  // Register a new user
  Future<bool> signUp(String email, String password, String? username) async {
    try {
      _setLoading(true);
      _clearError();

      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username ?? email.split('@')[0]},
      );

      _currentUser = response.user;

      if (_currentUser != null) {
        // Profile creation will be handled by the database trigger
        // No need to manually create profile here
        _saveUserDataToSecureStorage();
        _setLoading(false);
        return true;
      } else {
        _setError('Registration failed - please check your confirmation email');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Registration error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Sign in an existing user
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _currentUser = response.user;

      if (_currentUser != null) {
        _saveUserDataToSecureStorage();
        _setLoading(false);
        return true;
      } else {
        _setError('Sign in failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Sign in error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Sign out the current user
  Future<bool> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await supabase.auth.signOut();
      _currentUser = null;
      _clearUserDataFromSecureStorage();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Sign out error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await supabase.auth.resetPasswordForEmail(email);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Password reset error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({String? username, String? avatarUrl}) async {
    if (_currentUser == null) {
      _setError('No user signed in');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await supabase
          .from('user_profiles')
          .update(updates)
          .eq('user_id', _currentUser!.id);

      // Update metadata if username changed
      if (username != null) {
        await supabase.auth.updateUser(
          UserAttributes(data: {'username': username}),
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Profile update error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) {
      _setError('No user signed in');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      // First verify the old password by attempting to reauthenticate
      final email = _currentUser!.email;
      if (email == null) {
        _setError('User email not available');
        _setLoading(false);
        return false;
      }

      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: oldPassword,
        );
      } catch (e) {
        _setError('Current password is incorrect');
        _setLoading(false);
        return false;
      }

      // If verification succeeded, update the password
      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Password change error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Get a unique identifier for a user (for database encryption)
  String getUserEncryptionKey() {
    if (_currentUser == null) {
      // Return a generic key for users who aren't logged in
      return 'docln_secure_storage_generic_key';
    }

    // Create a unique identifier based on user ID
    final userIdBytes = utf8.encode(_currentUser!.id);
    final shaDigest = sha256.convert(userIdBytes);
    return shaDigest.toString();
  }

  // Set the last sync timestamp
  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    await _secureStorage.write(
      key: _lastSyncKey,
      value: timestamp.millisecondsSinceEpoch.toString(),
    );
  }

  // Get the last sync timestamp
  Future<DateTime?> getLastSyncTimestamp() async {
    final timestampString = await _secureStorage.read(key: _lastSyncKey);
    if (timestampString == null) return null;

    final timestamp = int.tryParse(timestampString);
    if (timestamp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // PRIVATE HELPER METHODS

  // Save user data to secure storage
  Future<void> _saveUserDataToSecureStorage() async {
    if (_currentUser != null) {
      final userData = jsonEncode({
        'id': _currentUser!.id,
        'email': _currentUser!.email,
        'metadata': _currentUser!.userMetadata,
      });

      await _secureStorage.write(key: _userDataKey, value: userData);

      // Store the token separately
      if (supabase.auth.currentSession?.accessToken != null) {
        await _secureStorage.write(
          key: _authTokenKey,
          value: supabase.auth.currentSession!.accessToken,
        );
      }
    }
  }

  // Clear user data from secure storage
  Future<void> _clearUserDataFromSecureStorage() async {
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: _authTokenKey);
    // Don't clear the last sync timestamp
  }

  // Set loading state
  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  // Set error message
  void _setError(String errorMessage) {
    _error = errorMessage;
    debugPrint('AuthService error: $_error');
    notifyListeners();
  }

  // Clear error message
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Dispose resources
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
