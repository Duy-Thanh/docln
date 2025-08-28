import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/bookmark_entity.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/exceptions.dart';
import '../datasources/bookmark_local_datasource.dart';
import '../models/bookmark_model.dart';

/// Implementation of bookmark repository for DCL2 architecture
@Injectable(as: BookmarkRepository)
class BookmarkRepositoryImpl implements BookmarkRepository {
  final BookmarkLocalDataSource localDataSource;
  
  BookmarkRepositoryImpl(this.localDataSource);
  
  @override
  Future<Either<Failure, List<BookmarkEntity>>> getBookmarks() async {
    try {
      final bookmarks = await localDataSource.getBookmarks();
      return Right(bookmarks);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, BookmarkEntity>> addBookmark(BookmarkEntity bookmark) async {
    try {
      final bookmarkModel = BookmarkModel.fromEntity(bookmark);
      final result = await localDataSource.addBookmark(bookmarkModel);
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> removeBookmark(String bookmarkId) async {
    try {
      final result = await localDataSource.removeBookmark(bookmarkId);
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> isBookmarked(String novelId) async {
    try {
      final result = await localDataSource.isBookmarked(novelId);
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, BookmarkEntity?>> getBookmarkByNovelId(String novelId) async {
    try {
      final result = await localDataSource.getBookmarkByNovelId(novelId);
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> toggleBookmark(BookmarkEntity bookmark) async {
    try {
      final isBookmarked = await localDataSource.isBookmarked(bookmark.novelId);
      
      if (isBookmarked) {
        // Find and remove existing bookmark
        final existingBookmark = await localDataSource.getBookmarkByNovelId(bookmark.novelId);
        if (existingBookmark != null) {
          await localDataSource.removeBookmark(existingBookmark.id);
          return const Right(false); // Removed
        }
      } else {
        // Add new bookmark
        await localDataSource.addBookmark(BookmarkModel.fromEntity(bookmark));
        return const Right(true); // Added
      }
      
      return const Right(false);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
  
  @override
  Future<Either<Failure, List<BookmarkEntity>>> searchBookmarks(String query) async {
    try {
      final bookmarks = await localDataSource.getBookmarks();
      final filteredBookmarks = bookmarks.where((bookmark) {
        return bookmark.title.toLowerCase().contains(query.toLowerCase()) ||
               (bookmark.author?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
      
      return Right(filteredBookmarks);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Unexpected error: $e'));
    }
  }
}