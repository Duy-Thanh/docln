import 'dart:convert';
import 'package:injectable/injectable.dart';
import '../../../../services/preferences_service.dart';
import '../../../core/errors/exceptions.dart';
import '../models/bookmark_model.dart';

/// Local data source for bookmarks using preferences
@injectable
class BookmarkLocalDataSource {
  final PreferencesService _preferencesService;
  static const String _bookmarksKey = 'dcl2_bookmarks';
  
  BookmarkLocalDataSource(this._preferencesService);
  
  /// Get all bookmarks from local storage
  Future<List<BookmarkModel>> getBookmarks() async {
    try {
      final bookmarksJson = _preferencesService.getString(_bookmarksKey);
      
      if (bookmarksJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
      return bookmarksList
          .map((json) => BookmarkModel.fromJson(json))
          .toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load bookmarks: $e');
    }
  }
  
  /// Save bookmarks to local storage
  Future<void> saveBookmarks(List<BookmarkModel> bookmarks) async {
    try {
      final bookmarksJson = jsonEncode(
        bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      );
      await _preferencesService.setString(_bookmarksKey, bookmarksJson);
    } catch (e) {
      throw CacheException(message: 'Failed to save bookmarks: $e');
    }
  }
  
  /// Add a single bookmark
  Future<BookmarkModel> addBookmark(BookmarkModel bookmark) async {
    try {
      final bookmarks = await getBookmarks();
      
      // Check if bookmark already exists
      final existingIndex = bookmarks.indexWhere(
        (b) => b.novelId == bookmark.novelId,
      );
      
      if (existingIndex != -1) {
        throw CacheException(message: 'Bookmark already exists');
      }
      
      bookmarks.add(bookmark);
      await saveBookmarks(bookmarks);
      return bookmark;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to add bookmark: $e');
    }
  }
  
  /// Remove a bookmark by ID
  Future<bool> removeBookmark(String bookmarkId) async {
    try {
      final bookmarks = await getBookmarks();
      final initialLength = bookmarks.length;
      
      bookmarks.removeWhere((bookmark) => bookmark.id == bookmarkId);
      
      if (bookmarks.length < initialLength) {
        await saveBookmarks(bookmarks);
        return true;
      }
      
      return false;
    } catch (e) {
      throw CacheException(message: 'Failed to remove bookmark: $e');
    }
  }
  
  /// Check if a novel is bookmarked
  Future<bool> isBookmarked(String novelId) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any((bookmark) => bookmark.novelId == novelId);
    } catch (e) {
      throw CacheException(message: 'Failed to check bookmark status: $e');
    }
  }
  
  /// Get bookmark by novel ID
  Future<BookmarkModel?> getBookmarkByNovelId(String novelId) async {
    try {
      final bookmarks = await getBookmarks();
      final bookmark = bookmarks.where(
        (b) => b.novelId == novelId,
      ).firstOrNull;
      return bookmark;
    } catch (e) {
      throw CacheException(message: 'Failed to get bookmark: $e');
    }
  }
  
  /// Migrate from DCL1 bookmarks
  Future<void> migrateFromDcl1() async {
    try {
      // Check if migration already done
      final migrationDone = _preferencesService.getBool(
        'dcl2_bookmarks_migrated',
        defaultValue: false,
      );
      
      if (migrationDone) return;
      
      // Get DCL1 bookmarks
      final dcl1BookmarksJson = _preferencesService.getString('bookmarked_novels');
      
      if (dcl1BookmarksJson.isNotEmpty) {
        final List<dynamic> dcl1Bookmarks = jsonDecode(dcl1BookmarksJson);
        final dcl2Bookmarks = <BookmarkModel>[];
        
        for (int i = 0; i < dcl1Bookmarks.length; i++) {
          final dcl1Bookmark = dcl1Bookmarks[i];
          final dcl2Bookmark = BookmarkModel.fromLightNovel(
            'bookmark_$i',
            dcl1Bookmark,
          );
          dcl2Bookmarks.add(dcl2Bookmark);
        }
        
        await saveBookmarks(dcl2Bookmarks);
      }
      
      // Mark migration as done
      await _preferencesService.setBool('dcl2_bookmarks_migrated', true);
    } catch (e) {
      throw CacheException(message: 'Failed to migrate bookmarks: $e');
    }
  }
}