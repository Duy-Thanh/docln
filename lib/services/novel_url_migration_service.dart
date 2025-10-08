import 'dart:convert';
import 'package:flutter/material.dart';
import 'preferences_service.dart';
import 'server_management_service.dart';

/// Novel URL Migration Service
/// 
/// Fixes corrupted novel URLs in bookmarks caused by server changes.
/// Converts all absolute URLs to relative paths for server-independent storage.
class NovelUrlMigrationService {
  static final NovelUrlMigrationService _instance =
      NovelUrlMigrationService._internal();
  factory NovelUrlMigrationService() => _instance;
  NovelUrlMigrationService._internal();

  final PreferencesService _prefsService = PreferencesService();
  final ServerManagementService _serverService = ServerManagementService();
  
  static const String _bookmarksKey = 'bookmarked_novels';
  static const String _migrationVersionKey = 'novel_url_migration_version';
  static const int currentMigrationVersion = 1;

  /// Check if migration is needed
  Future<bool> needsMigration() async {
    try {
      await _prefsService.initialize();
      
      final version = _prefsService.getInt(
        _migrationVersionKey,
        defaultValue: 0,
      );
      
      return version < currentMigrationVersion;
    } catch (e) {
      debugPrint('❌ Error checking migration status: $e');
      return true; // Assume migration needed on error
    }
  }

  /// Run migration to fix novel URLs
  Future<bool> migrateNovelUrls() async {
    try {
      debugPrint('🔄 Starting novel URL migration...');
      
      await _prefsService.initialize();
      await _serverService.initialize();
      
      // Check if migration needed
      if (!await needsMigration()) {
        debugPrint('✅ Migration not needed');
        return true;
      }

      // Load bookmarked novels
      final String bookmarksJson = _prefsService.getString(
        _bookmarksKey,
        defaultValue: '[]',
      );
      
      if (bookmarksJson == '[]') {
        debugPrint('ℹ️ No bookmarks to migrate');
        await _markMigrationComplete();
        return true;
      }

      final List<dynamic> bookmarksList = jsonDecode(bookmarksJson);
      
      if (bookmarksList.isEmpty) {
        debugPrint('ℹ️ No bookmarks to migrate');
        await _markMigrationComplete();
        return true;
      }

      debugPrint('📚 Found ${bookmarksList.length} bookmarks to migrate');
      
      // Migrate each novel
      int migratedCount = 0;
      int errorCount = 0;
      final List<Map<String, dynamic>> migratedNovels = [];

      for (var novelJson in bookmarksList) {
        try {
          final migratedNovel = _migrateNovelUrl(novelJson);
          migratedNovels.add(migratedNovel);
          migratedCount++;
        } catch (e) {
          debugPrint('⚠️ Error migrating novel: $e');
          errorCount++;
          // Keep original on error
          migratedNovels.add(novelJson);
        }
      }

      // Save migrated novels
      final migratedJson = jsonEncode(migratedNovels);
      await _prefsService.setString(_bookmarksKey, migratedJson);
      
      // Mark migration complete
      await _markMigrationComplete();
      
      debugPrint('✅ Migration complete:');
      debugPrint('   Migrated: $migratedCount');
      debugPrint('   Errors: $errorCount');
      debugPrint('   Total: ${bookmarksList.length}');
      
      return true;
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      return false;
    }
  }

  /// Migrate a single novel's URL
  Map<String, dynamic> _migrateNovelUrl(Map<String, dynamic> novelJson) {
    // Create a copy to avoid modifying original
    final Map<String, dynamic> migratedNovel = Map.from(novelJson);
    
    // Migrate main URL
    if (migratedNovel.containsKey('url')) {
      final String originalUrl = migratedNovel['url'] as String;
      final String relativePath = _serverService.toRelativePath(originalUrl);
      final String newUrl = _serverService.toAbsoluteUrl(relativePath);
      
      migratedNovel['url'] = newUrl;
      
      debugPrint('   Migrated URL: $originalUrl → $newUrl');
    }

    // Migrate cover URL (usually CDN, but let's be safe)
    if (migratedNovel.containsKey('coverUrl')) {
      final String coverUrl = migratedNovel['coverUrl'] as String;
      
      // Only migrate if it's from a known server
      if (_serverService.extractServerFromUrl(coverUrl) != _serverService.currentServer) {
        final relativePath = _serverService.toRelativePath(coverUrl);
        
        // Check if it's a valid novel-related path
        if (relativePath.contains('/img/') || 
            relativePath.contains('/cover/') ||
            relativePath.contains('/thumb/')) {
          final newCoverUrl = _serverService.toAbsoluteUrl(relativePath);
          migratedNovel['coverUrl'] = newCoverUrl;
          
          debugPrint('   Migrated cover: $coverUrl → $newCoverUrl');
        }
      }
    }

    return migratedNovel;
  }

  /// Mark migration as complete
  Future<void> _markMigrationComplete() async {
    await _prefsService.setInt(
      _migrationVersionKey,
      currentMigrationVersion,
    );
  }

  /// Force re-migration (for testing or recovery)
  Future<void> forceMigration() async {
    await _prefsService.setInt(_migrationVersionKey, 0);
    await migrateNovelUrls();
  }

  /// Get migration status information
  Future<Map<String, dynamic>> getMigrationInfo() async {
    try {
      await _prefsService.initialize();
      
      final version = _prefsService.getInt(
        _migrationVersionKey,
        defaultValue: 0,
      );
      
      final bookmarksJson = _prefsService.getString(
        _bookmarksKey,
        defaultValue: '[]',
      );
      
      final bookmarksList = jsonDecode(bookmarksJson) as List<dynamic>;
      
      // Check for corrupted URLs
      int corruptedCount = 0;
      for (var novelJson in bookmarksList) {
        final url = novelJson['url'] as String?;
        if (url != null && 
            url.startsWith('http') && 
            !_serverService.isCurrentServer(url)) {
          corruptedCount++;
        }
      }

      return {
        'migrationVersion': version,
        'currentVersion': currentMigrationVersion,
        'needsMigration': version < currentMigrationVersion,
        'totalNovels': bookmarksList.length,
        'corruptedUrls': corruptedCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting migration info: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}
