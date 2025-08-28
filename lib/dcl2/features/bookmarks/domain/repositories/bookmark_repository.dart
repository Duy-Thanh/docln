import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../entities/bookmark_entity.dart';

/// Repository interface for bookmarks in DCL2 architecture
abstract class BookmarkRepository {
  /// Get all bookmarks
  Future<Either<Failure, List<BookmarkEntity>>> getBookmarks();
  
  /// Add a bookmark
  Future<Either<Failure, BookmarkEntity>> addBookmark(BookmarkEntity bookmark);
  
  /// Remove a bookmark by ID
  Future<Either<Failure, bool>> removeBookmark(String bookmarkId);
  
  /// Check if a novel is bookmarked
  Future<Either<Failure, bool>> isBookmarked(String novelId);
  
  /// Toggle bookmark status
  Future<Either<Failure, bool>> toggleBookmark(BookmarkEntity bookmark);
  
  /// Search bookmarks
  Future<Either<Failure, List<BookmarkEntity>>> searchBookmarks(String query);
  
  /// Get bookmark by novel ID
  Future<Either<Failure, BookmarkEntity?>> getBookmarkByNovelId(String novelId);
}