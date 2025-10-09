import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'preferences_service.dart';
import 'novel_database_service.dart';
import 'server_management_service.dart';
import '../modules/light_novel.dart';

/// Novel Data Migration Service
///
/// Migrates bookmarks and reading history from the old JSON-based storage
/// to the new database-based storage with server-independent data.
class NovelDataMigrationService {
  static final NovelDataMigrationService _instance =
      NovelDataMigrationService._internal();
  factory NovelDataMigrationService() => _instance;
  NovelDataMigrationService._internal();

  final PreferencesService _prefsService = PreferencesService();
  final NovelDatabaseService _dbService = NovelDatabaseService();
  final ServerManagementService _serverService = ServerManagementService();

  // Keys for old storage
  static const String _bookmarksKey = 'bookmarked_novels';
  static const String _historyKey = 'reading_history';
  static const String _migrationCompleteKey =
      'novel_data_migration_complete_v2';

  /// Check if migration is needed
  Future<bool> needsMigration() async {
    try {
      await _prefsService.initialize();

      // Check if already migrated
      final migrated = _prefsService.getBool(
        _migrationCompleteKey,
        defaultValue: false,
      );

      if (migrated) {
        debugPrint('ℹ️ Novel data already migrated');
        return false;
      }

      // Check if there's any old data to migrate
      final bookmarksJson = _prefsService.getString(_bookmarksKey);
      final historyJson = _prefsService.getString(_historyKey);

      return bookmarksJson.isNotEmpty || historyJson.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking migration status: $e');
      return false;
    }
  }

  /// Run the complete migration
  Future<bool> migrate() async {
    try {
      debugPrint('🔄 Starting novel data migration to database...');

      await _prefsService.initialize();
      await _dbService.initialize();
      await _serverService.initialize();

      // Check if migration needed
      if (!await needsMigration()) {
        return true;
      }

      final currentServer = _serverService.currentServer;

      // Migrate bookmarks
      final bookmarkResult = await _migrateBookmarks(currentServer);
      debugPrint(
        '📚 Bookmarks migration: ${bookmarkResult ? "✅ SUCCESS" : "❌ FAILED"}',
      );

      // Migrate reading history
      final historyResult = await _migrateHistory(currentServer);
      debugPrint(
        '📖 History migration: ${historyResult ? "✅ SUCCESS" : "❌ FAILED"}',
      );

      if (bookmarkResult && historyResult) {
        // Mark migration as complete
        await _prefsService.setBool(_migrationCompleteKey, true);

        // Get statistics
        final stats = await _dbService.getStats();
        debugPrint('✅ Migration complete!');
        debugPrint('   Novels: ${stats['novels']}');
        debugPrint('   Bookmarks: ${stats['bookmarks']}');
        debugPrint('   History: ${stats['history']}');

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Migrate bookmarks from JSON to database
  Future<bool> _migrateBookmarks(String currentServer) async {
    try {
      final bookmarksJson = _prefsService.getString(_bookmarksKey);

      if (bookmarksJson.isEmpty || bookmarksJson == '[]') {
        debugPrint('ℹ️ No bookmarks to migrate');
        return true;
      }

      final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
      debugPrint('📚 Migrating ${bookmarksList.length} bookmarks...');

      int successCount = 0;
      int errorCount = 0;

      for (var novelJson in bookmarksList) {
        try {
          final novel = LightNovel.fromJson(novelJson);

          // Add to database
          final success = await _dbService.addBookmark(novel);

          if (success) {
            successCount++;
          } else {
            errorCount++;
            debugPrint('⚠️ Failed to migrate bookmark: ${novel.title}');
          }
        } catch (e) {
          errorCount++;
          debugPrint('⚠️ Error migrating bookmark: $e');
        }
      }

      debugPrint('   Migrated: $successCount/${bookmarksList.length}');
      if (errorCount > 0) {
        debugPrint('   Errors: $errorCount');
      }

      return errorCount == 0;
    } catch (e) {
      debugPrint('❌ Error migrating bookmarks: $e');
      return false;
    }
  }

  /// Migrate reading history from JSON to database
  Future<bool> _migrateHistory(String currentServer) async {
    try {
      final historyJson = _prefsService.getString(_historyKey);

      if (historyJson.isEmpty || historyJson == '[]') {
        debugPrint('ℹ️ No reading history to migrate');
        return true;
      }

      final List<dynamic> historyList = jsonDecode(historyJson);
      debugPrint('📖 Migrating ${historyList.length} history items...');

      int successCount = 0;
      int errorCount = 0;

      for (var historyJson in historyList) {
        try {
          // Parse history item
          final novelJson = historyJson['novel'];
          final lastReadChapter =
              historyJson['lastReadChapter'] as String? ?? 'Unknown';

          final novel = LightNovel.fromJson(novelJson);

          // Add to database
          await _dbService.addToHistory(novel, lastReadChapter);
          successCount++;
        } catch (e) {
          errorCount++;
          debugPrint('⚠️ Error migrating history item: $e');
        }
      }

      debugPrint('   Migrated: $successCount/${historyList.length}');
      if (errorCount > 0) {
        debugPrint('   Errors: $errorCount');
      }

      return errorCount == 0;
    } catch (e) {
      debugPrint('❌ Error migrating history: $e');
      return false;
    }
  }

  /// Clean up old JSON data after successful migration
  Future<void> cleanupOldData() async {
    try {
      debugPrint('🧹 Cleaning up old JSON data...');

      // Backup old data first
      final bookmarksJson = _prefsService.getString(_bookmarksKey);
      final historyJson = _prefsService.getString(_historyKey);

      if (bookmarksJson.isNotEmpty) {
        await _prefsService.setString('${_bookmarksKey}_backup', bookmarksJson);
      }

      if (historyJson.isNotEmpty) {
        await _prefsService.setString('${_historyKey}_backup', historyJson);
      }

      // Clear old data
      await _prefsService.remove(_bookmarksKey);
      await _prefsService.remove(_historyKey);

      debugPrint('✅ Old data cleaned up (backups saved)');
    } catch (e) {
      debugPrint('⚠️ Error cleaning up old data: $e');
    }
  }

  /// Force re-migration (for testing or recovery)
  Future<void> forceMigration() async {
    await _prefsService.setBool(_migrationCompleteKey, false);
    await migrate();
  }

  /// Get migration status information
  Future<Map<String, dynamic>> getMigrationInfo() async {
    try {
      await _prefsService.initialize();

      final migrated = _prefsService.getBool(
        _migrationCompleteKey,
        defaultValue: false,
      );

      // Count old data
      int oldBookmarksCount = 0;
      int oldHistoryCount = 0;

      try {
        final bookmarksJson = _prefsService.getString(_bookmarksKey);
        if (bookmarksJson.isNotEmpty && bookmarksJson != '[]') {
          final bookmarksList = jsonDecode(bookmarksJson) as List;
          oldBookmarksCount = bookmarksList.length;
        }
      } catch (e) {
        debugPrint('⚠️ Error counting old bookmarks: $e');
      }

      try {
        final historyJson = _prefsService.getString(_historyKey);
        if (historyJson.isNotEmpty && historyJson != '[]') {
          final historyList = jsonDecode(historyJson) as List;
          oldHistoryCount = historyList.length;
        }
      } catch (e) {
        debugPrint('⚠️ Error counting old history: $e');
      }

      // Get new database stats
      final dbStats = await _dbService.getStats();

      return {
        'migrated': migrated,
        'needsMigration': await needsMigration(),
        'oldData': {'bookmarks': oldBookmarksCount, 'history': oldHistoryCount},
        'newData': dbStats,
      };
    } catch (e) {
      debugPrint('❌ Error getting migration info: $e');
      return {};
    }
  }

  /// Restore from backup (emergency recovery)
  Future<bool> restoreFromBackup() async {
    try {
      debugPrint('🔄 Restoring from backup...');

      final backupBookmarks = _prefsService.getString(
        '${_bookmarksKey}_backup',
      );
      final backupHistory = _prefsService.getString('${_historyKey}_backup');

      if (backupBookmarks.isNotEmpty) {
        await _prefsService.setString(_bookmarksKey, backupBookmarks);
        debugPrint('✅ Restored bookmarks backup');
      }

      if (backupHistory.isNotEmpty) {
        await _prefsService.setString(_historyKey, backupHistory);
        debugPrint('✅ Restored history backup');
      }

      // Reset migration flag to allow re-migration
      await _prefsService.setBool(_migrationCompleteKey, false);

      return true;
    } catch (e) {
      debugPrint('❌ Error restoring from backup: $e');
      return false;
    }
  }

  /// Fix migration with corrected URL handling
  /// This clears the database and re-migrates from backup with proper URL preservation
  Future<bool> fixMigration() async {
    try {
      debugPrint('🔧 Starting migration fix...');

      // Step 1: Clear the database
      debugPrint('   1️⃣ Clearing database...');
      await _dbService.clearAllData();

      // Step 2: Restore from backup
      debugPrint('   2️⃣ Restoring from backup...');
      final restored = await restoreFromBackup();
      if (!restored) {
        debugPrint('❌ Failed to restore from backup');
        return false;
      }

      // Step 3: Re-run migration with fixed URL logic
      debugPrint('   3️⃣ Re-migrating with fixed URL handling...');
      final success = await migrate();

      if (success) {
        debugPrint('✅ Migration fix completed successfully!');

        // Clean up old data again
        await cleanupOldData();

        return true;
      } else {
        debugPrint('❌ Migration fix failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error fixing migration: $e');
      return false;
    }
  }
}
