import 'package:flutter/material.dart';
import 'package:docln/core/models/light_novel.dart';
import 'novel_database_service.dart';
import 'server_management_service.dart';
import 'notification_service.dart';
import 'background_notification_service.dart';

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
  final NotificationService _notificationService = NotificationService();
  final BackgroundNotificationService _backgroundService =
      BackgroundNotificationService();

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

        // Auto-enable notifications for this novel
        await _enableNotificationsForNovel(novel);

        // 📤 IMPORTANT: Sync with server immediately to register for notifications
        await _syncWithServer();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error adding bookmark: $e');
      return false;
    }
  }

  /// Auto-enable notifications when bookmarking
  Future<void> _enableNotificationsForNovel(LightNovel novel) async {
    try {
      // Initialize notification service if needed
      await _notificationService.init();

      // Check if notifications are globally enabled
      final isEnabled = await _notificationService.isNotificationEnabled();

      if (!isEnabled) {
        // Request permission first
        debugPrint('📢 Requesting notification permission for ${novel.title}');
        final granted = await _notificationService.requestPermission();

        if (granted) {
          await _notificationService.setNotificationEnabled(true);

          // Start background service
          await _backgroundService.initialize();
          await _backgroundService.startPeriodicChecks();

          debugPrint('✅ Notifications enabled for ${novel.title}');
        } else {
          debugPrint('⚠️ Notification permission denied');
        }
      } else {
        debugPrint('✅ Notifications already enabled for ${novel.title}');
      }
    } catch (e) {
      debugPrint('❌ Error enabling notifications: $e');
    }
  }

  /// Remove a bookmark
  Future<bool> removeBookmark(String novelId) async {
    try {
      final success = await _dbService.removeBookmark(novelId);

      if (success) {
        await loadBookmarks(); // Reload to get updated list
        debugPrint('✅ Removed bookmark: $novelId');
        
        // 📤 IMPORTANT: Sync with server immediately to unregister notifications
        await _syncWithServer();
        
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      return false;
    }
  }

  /// Sync bookmarks with server for notifications
  Future<void> _syncWithServer() async {
    try {
      debugPrint('📤 Syncing bookmarks with notification server...');
      await _backgroundService.initialize();
      
      // Use the background service's sync method
      // This will send all current bookmarks to the server
      await _backgroundService.startPeriodicChecks();
      
      debugPrint('✅ Bookmarks synced with server');
    } catch (e) {
      debugPrint('⚠️ Error syncing with server (will retry later): $e');
      // Don't throw - bookmark operation already succeeded locally
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
