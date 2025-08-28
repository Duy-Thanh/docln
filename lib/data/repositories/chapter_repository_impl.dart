import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/repositories/chapter_repository.dart';
import '../models/chapter_model.dart';
import '../datasources/local/chapter_local_data_source.dart';
import '../datasources/remote/chapter_remote_data_source.dart';

@Injectable(as: ChapterRepository)
class ChapterRepositoryImpl implements ChapterRepository {
  final ChapterRemoteDataSource _remoteDataSource;
  final ChapterLocalDataSource _localDataSource;

  ChapterRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
  );

  @override
  Future<Either<Failure, List<ChapterEntity>>> getChapters(String novelId) async {
    try {
      // Try cache first
      final cachedChapters = await _localDataSource.getCachedChapters(novelId);
      if (cachedChapters.isNotEmpty) {
        return Right(cachedChapters);
      }

      // Fetch from remote
      final remoteChapters = await _remoteDataSource.getChapters(novelId);

      // Cache the results
      await _localDataSource.cacheChapters(remoteChapters);

      return Right(remoteChapters);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChapterEntity>> getChapter(String id) async {
    try {
      // Try cache first
      final cachedChapter = await _localDataSource.getCachedChapter(id);
      if (cachedChapter != null) {
        return Right(cachedChapter);
      }

      // Fetch from remote
      final remoteChapter = await _remoteDataSource.getChapter(id);

      // Cache the result
      await _localDataSource.cacheChapter(remoteChapter);

      return Right(remoteChapter);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> getChapterContent(String id) async {
    try {
      // Try cache first
      final cachedContent = await _localDataSource.getCachedChapterContent(id);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        return Right(cachedContent);
      }

      // Fetch from remote
      final remoteContent = await _remoteDataSource.getChapterContent(id);

      // Cache the content
      await _localDataSource.cacheChapterContent(id, remoteContent);

      return Right(remoteContent);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> saveChapter(ChapterEntity chapter) async {
    try {
      final model = ChapterModel.fromEntity(chapter);
      await _localDataSource.cacheChapter(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> markChapterAsRead(String id) async {
    try {
      await _localDataSource.markChapterAsRead(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<ChapterEntity>>> watchChapters(String novelId) async* {
    // This would typically use a stream from the database
    // For simplicity, we'll emit the current cached data
    try {
      final chapters = await _localDataSource.getCachedChapters(novelId);
      yield Right(chapters);
    } on CacheException catch (e) {
      yield Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChapterEntity?>> getNextChapter(String currentChapterId, String novelId) async {
    try {
      final chapters = await _localDataSource.getCachedChapters(novelId);
      if (chapters.isEmpty) {
        // Try to fetch from remote if cache is empty
        final remoteChapters = await _remoteDataSource.getChapters(novelId);
        await _localDataSource.cacheChapters(remoteChapters);
        return _findNextChapter(currentChapterId, remoteChapters);
      }
      return _findNextChapter(currentChapterId, chapters);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ChapterEntity?>> getPreviousChapter(String currentChapterId, String novelId) async {
    try {
      final chapters = await _localDataSource.getCachedChapters(novelId);
      if (chapters.isEmpty) {
        // Try to fetch from remote if cache is empty
        final remoteChapters = await _remoteDataSource.getChapters(novelId);
        await _localDataSource.cacheChapters(remoteChapters);
        return _findPreviousChapter(currentChapterId, remoteChapters);
      }
      return _findPreviousChapter(currentChapterId, chapters);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Either<Failure, ChapterEntity?> _findNextChapter(String currentChapterId, List<ChapterEntity> chapters) {
    try {
      // Sort chapters by chapter number or creation date
      final sortedChapters = chapters.toList()
        ..sort((a, b) {
          if (a.chapterNumber != null && b.chapterNumber != null) {
            return a.chapterNumber!.compareTo(b.chapterNumber!);
          }
          if (a.createdAt != null && b.createdAt != null) {
            return a.createdAt!.compareTo(b.createdAt!);
          }
          return 0;
        });

      final currentIndex = sortedChapters.indexWhere((chapter) => chapter.id == currentChapterId);
      if (currentIndex == -1 || currentIndex >= sortedChapters.length - 1) {
        return const Right(null); // No next chapter
      }

      return Right(sortedChapters[currentIndex + 1]);
    } catch (e) {
      return Left(CacheFailure('Failed to find next chapter: ${e.toString()}'));
    }
  }

  Either<Failure, ChapterEntity?> _findPreviousChapter(String currentChapterId, List<ChapterEntity> chapters) {
    try {
      // Sort chapters by chapter number or creation date
      final sortedChapters = chapters.toList()
        ..sort((a, b) {
          if (a.chapterNumber != null && b.chapterNumber != null) {
            return a.chapterNumber!.compareTo(b.chapterNumber!);
          }
          if (a.createdAt != null && b.createdAt != null) {
            return a.createdAt!.compareTo(b.createdAt!);
          }
          return 0;
        });

      final currentIndex = sortedChapters.indexWhere((chapter) => chapter.id == currentChapterId);
      if (currentIndex <= 0) {
        return const Right(null); // No previous chapter
      }

      return Right(sortedChapters[currentIndex - 1]);
    } catch (e) {
      return Left(CacheFailure('Failed to find previous chapter: ${e.toString()}'));
    }
  }
}
