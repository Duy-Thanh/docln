import 'package:flutter/material.dart';
import '../modules/light_novel.dart';
import 'novel_database_service.dart';
import 'server_management_service.dart';

/// Bookmark Service V2
///
/// Uses the new database-based storage instead of JSON serialization.
/// This fixes the critical bug where server changes destroy bookmarks.
class BookmarkServiceV2 extends ChangeNotifier {
  static final BookmarkServiceV2 _instance = BookmarkServiceV2._internal();
  factory BookmarkServiceV2() => _instance;

  BookmarkServiceV2._internal();

  final NovelDatabaseService _dbService = NovelDatabaseService();
  final ServerManagementService _serverService = ServerManagementService();

  List<LightNovel> _bookmarkedNovels = [];

  List<LightNovel> get bookmarkedNovels => _bookmarkedNovels;

  Future<void> init() async {
    await _dbService.initialize();
    await _serverService.initialize();
    await loadBookmarks();
  }

  /// Load bookmarks from database
  Future<void> loadBookmarks() async {
    try {
      final currentServer = _serverService.currentServer;
      _bookmarkedNovels = await _dbService.getBookmarks(currentServer);

      debugPrint(
        '✅ Loaded ${_bookmarkedNovels.length} bookmarks from database',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading bookmarks: $e');
      _bookmarkedNovels = [];
      notifyListeners();
    }
  }

  /// Add a bookmark
  Future<bool> addBookmark(LightNovel novel) async {
    try {
      // Check if already bookmarked
      if (_isBookmarked(novel.id)) {
        return false;
      }

      final success = await _dbService.addBookmark(novel);

      if (success) {
        await loadBookmarks(); // Reload to get updated list
        debugPrint('✅ Added bookmark: ${novel.title}');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error adding bookmark: $e');
      return false;
    }
  }

  /// Remove a bookmark
  Future<bool> removeBookmark(String novelId) async {
    try {
      final success = await _dbService.removeBookmark(novelId);

      if (success) {
        await loadBookmarks(); // Reload to get updated list
        debugPrint('✅ Removed bookmark: $novelId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      return false;
    }
  }

  /// Check if a novel is bookmarked
  bool _isBookmarked(String novelId) {
    return _bookmarkedNovels.any((novel) => novel.id == novelId);
  }

  /// Check if a novel is bookmarked (public)
  bool isBookmarked(String novelId) {
    return _isBookmarked(novelId);
  }

  /// Toggle bookmark
  Future<void> toggleBookmark(LightNovel novel) async {
    if (_isBookmarked(novel.id)) {
      await removeBookmark(novel.id);
    } else {
      await addBookmark(novel);
    }
  }

  /// Get bookmark count
  int get bookmarkCount => _bookmarkedNovels.length;

  /// Search bookmarks by title
  List<LightNovel> searchBookmarks(String query) {
    if (query.isEmpty) return _bookmarkedNovels;

    final lowerQuery = query.toLowerCase();
    return _bookmarkedNovels.where((novel) {
      return novel.title.toLowerCase().contains(lowerQuery) ||
          (novel.alternativeTitles?.any(
                (alt) => alt.toLowerCase().contains(lowerQuery),
              ) ??
              false);
    }).toList();
  }

  /// Reload bookmarks when server changes
  Future<void> onServerChange() async {
    debugPrint('🔄 Server changed, reloading bookmarks...');
    await loadBookmarks();
  }
}
