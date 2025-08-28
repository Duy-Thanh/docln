import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart' as app_exceptions;
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_data_source.dart';
import '../datasources/remote/auth_remote_data_source.dart';

@Injectable(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  AuthRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._networkInfo,
  );

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final userModel = await _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );

      // Cache the user locally
      await _localDataSource.cacheUser(userModel);

      return Right(userModel);
    } on app_exceptions.AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on app_exceptions.ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final userModel = await _remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Cache the user locally
      await _localDataSource.cacheUser(userModel);

      return Right(userModel);
    } on app_exceptions.AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on app_exceptions.ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      // Try to sign out remotely if connected
      if (await _networkInfo.isConnected) {
        await _remoteDataSource.signOut();
      }

      // Clear local cache
      await _localDataSource.clearCachedUser();
      await _localDataSource.clearAuthToken();

      return const Right(null);
    } on app_exceptions.AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on app_exceptions.CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      // Try to get from remote if connected
      if (await _networkInfo.isConnected) {
        final userModel = await _remoteDataSource.getCurrentUser();
        if (userModel != null) {
          // Update local cache
          await _localDataSource.cacheUser(userModel);
          return Right(userModel);
        }
      }

      // Fallback to cached user
      final cachedUser = await _localDataSource.getCachedUser();
      return Right(cachedUser);
    } on app_exceptions.AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on app_exceptions.CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      await _remoteDataSource.resetPassword(email);
      return const Right(null);
    } on app_exceptions.AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on app_exceptions.ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Stream<Either<Failure, UserEntity?>> watchAuthState() async* {
    try {
      await for (final userModel in _remoteDataSource.watchAuthState()) {
        if (userModel != null) {
          // Cache the user when auth state changes
          await _localDataSource.cacheUser(userModel);
        } else {
          // Clear cache when signed out
          await _localDataSource.clearCachedUser();
          await _localDataSource.clearAuthToken();
        }

        yield Right(userModel);
      }
    } catch (e) {
      yield Left(AuthFailure('Auth state error: ${e.toString()}'));
    }
  }
}
