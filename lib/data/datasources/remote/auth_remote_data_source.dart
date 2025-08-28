import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exceptions.dart' as app_exceptions;
import '../../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUser();

  Future<void> resetPassword(String email);

  Stream<UserModel?> watchAuthState();
}

@Injectable(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _supabaseClient;

  AuthRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw app_exceptions.AuthException('Sign in failed');
      }

      final user = response.user!;
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        avatarUrl: user.userMetadata?['avatar_url'],
        createdAt: DateTime.parse(user.createdAt),
        lastLoginAt: DateTime.now(),
      );
    } catch (e) {
      throw app_exceptions.AuthException('Failed to sign in: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (response.user == null) {
        throw app_exceptions.AuthException('Sign up failed');
      }

      final user = response.user!;
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        createdAt: DateTime.parse(user.createdAt),
      );
    } catch (e) {
      throw app_exceptions.AuthException('Failed to sign up: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
    } catch (e) {
      throw app_exceptions.AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return null;

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        avatarUrl: user.userMetadata?['avatar_url'],
        createdAt: DateTime.parse(user.createdAt),
      );
    } catch (e) {
      throw app_exceptions.AuthException('Failed to get current user: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw app_exceptions.AuthException('Failed to reset password: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> watchAuthState() async* {
    await for (final authState in _supabaseClient.auth.onAuthStateChange) {
      final user = authState.session?.user;
      if (user == null) {
        yield null;
      } else {
        yield UserModel(
          id: user.id,
          email: user.email ?? '',
          displayName: user.userMetadata?['display_name'],
          avatarUrl: user.userMetadata?['avatar_url'],
          createdAt: DateTime.parse(user.createdAt),
        );
      }
    }
  }
}
