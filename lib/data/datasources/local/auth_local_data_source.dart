import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/exceptions.dart' as app_exceptions;
import '../../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);

  Future<UserModel?> getCachedUser();

  Future<void> clearCachedUser();

  Future<void> cacheAuthToken(String token);

  Future<String?> getCachedAuthToken();

  Future<void> clearAuthToken();
}

@Injectable(as: AuthLocalDataSource)
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _userKey = 'cached_user';
  static const String _authTokenKey = 'auth_token';

  final SharedPreferences _sharedPreferences;

  AuthLocalDataSourceImpl(this._sharedPreferences);

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = user.toJson();
      await _sharedPreferences.setString(_userKey, userJson.toString());
    } catch (e) {
      throw app_exceptions.CacheException('Failed to cache user: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final userJsonString = _sharedPreferences.getString(_userKey);
      if (userJsonString == null) return null;

      // Parse the JSON string back to a map
      final userJson = _parseJsonString(userJsonString);
      return UserModel.fromJson(userJson);
    } catch (e) {
      throw app_exceptions.CacheException('Failed to get cached user: ${e.toString()}');
    }
  }

  @override
  Future<void> clearCachedUser() async {
    try {
      await _sharedPreferences.remove(_userKey);
    } catch (e) {
      throw app_exceptions.CacheException('Failed to clear cached user: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheAuthToken(String token) async {
    try {
      await _sharedPreferences.setString(_authTokenKey, token);
    } catch (e) {
      throw app_exceptions.CacheException('Failed to cache auth token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getCachedAuthToken() async {
    try {
      return _sharedPreferences.getString(_authTokenKey);
    } catch (e) {
      throw app_exceptions.CacheException('Failed to get cached auth token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAuthToken() async {
    try {
      await _sharedPreferences.remove(_authTokenKey);
    } catch (e) {
      throw app_exceptions.CacheException('Failed to clear auth token: ${e.toString()}');
    }
  }

  Map<String, dynamic> _parseJsonString(String jsonString) {
    // Simple JSON parsing for basic key-value pairs
    // In a real app, you might want to use json.decode
    final Map<String, dynamic> result = {};

    // Remove braces and split by commas
    final content = jsonString.substring(1, jsonString.length - 1);
    final pairs = content.split(',');

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim().replaceAll('"', '');
        final value = keyValue[1].trim().replaceAll('"', '');

        // Try to parse as different types
        if (value == 'null') {
          result[key] = null;
        } else if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }
}
