import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/entities/light_novel.dart';
import '../../../domain/repositories/light_novel_repository.dart';
import '../models/light_novel_model.dart';
import '../datasources/local/light_novel_local_data_source.dart';
import '../datasources/remote/light_novel_remote_data_source.dart';

@Injectable(as: LightNovelRepository)
class LightNovelRepositoryImpl implements LightNovelRepository {
  final LightNovelRemoteDataSource _remoteDataSource;
  final LightNovelLocalDataSource _localDataSource;
  final ApiClient _apiClient;

  LightNovelRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._apiClient,
  );

  @override
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Try to get from cache first
      final cachedNovels = await _localDataSource.getCachedLightNovels();

      // If we have cached data and no internet, return cached data
      if (cachedNovels.isNotEmpty && !(await _apiClient.isConnected)) {
        return Right(cachedNovels);
      }

      // Try to fetch from remote
      final remoteNovels = await _remoteDataSource.getLightNovels(
        page: page,
        limit: limit,
      );

      // Cache the remote data
      await _localDataSource.cacheLightNovels(remoteNovels);

      return Right(remoteNovels);
    } on ServerException catch (e) {
      // If server fails and we have cache, return cache
      try {
        final cachedNovels = await _localDataSource.getCachedLightNovels();
        if (cachedNovels.isNotEmpty) {
          return Right(cachedNovels);
        }
      } catch (_) {
        // Cache also failed
      }
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, LightNovelEntity>> getLightNovel(String id) async {
    try {
      // Try cache first
      final cachedNovel = await _localDataSource.getCachedLightNovel(id);
      if (cachedNovel != null) {
        return Right(cachedNovel);
      }

      // Fetch from remote
      final remoteNovel = await _remoteDataSource.getLightNovel(id);

      // Cache the result
      await _localDataSource.cacheLightNovel(remoteNovel);

      return Right(remoteNovel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> saveLightNovel(LightNovelEntity novel) async {
    try {
      final model = LightNovelModel.fromEntity(novel);
      await _localDataSource.cacheLightNovel(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeLightNovel(String id) async {
    try {
      await _localDataSource.removeLightNovel(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<LightNovelEntity>>> searchLightNovels(
    String query,
  ) async {
    try {
      // For now, search in local cache
      // In a real implementation, you might want to search remotely
      final cachedNovels = await _localDataSource.getCachedLightNovels();
      final filteredNovels = cachedNovels
          .where((novel) =>
              novel.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return Right(filteredNovels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<LightNovelEntity>>> watchLightNovels() async* {
    // This would typically use a stream from the database
    // For simplicity, we'll emit the current cached data
    try {
      final novels = await _localDataSource.getCachedLightNovels();
      yield Right(novels);
    } on CacheException catch (e) {
      yield Left(CacheFailure(e.message));
    }
  }
}
