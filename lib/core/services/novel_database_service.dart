import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:docln/core/models/light_novel.dart';

/// Novel Database Service
///
/// Stores bookmarks and reading history in a proper SQLite database
/// with normalized, server-independent data storage.
///
/// This replaces the problematic JSON serialization approach that breaks
/// when server URLs change.
class NovelDatabaseService {
  // Singleton pattern
  static final NovelDatabaseService _instance =
      NovelDatabaseService._internal();
  factory NovelDatabaseService() => _instance;
  NovelDatabaseService._internal();

  // Constants
  static const String _dbName = 'novels.db';
  static const int _dbVersion = 1;

  // Internal state
  Database? _db;
  bool _initialized = false;

  /// Initialize the database
  Future<void> initialize() async {
    if (_initialized && _db != null) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/$_dbName';

      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _initialized = true;
      debugPrint('✅ NovelDatabaseService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing novel database: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Novels table - stores base novel information
    // Uses relative paths instead of absolute URLs for server independence
    await db.execute('''
      CREATE TABLE novels (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        relative_url TEXT NOT NULL,
        relative_cover_url TEXT,
        chapters INTEGER,
        latest_chapter TEXT,
        volume_title TEXT,
        rating REAL,
        reviews INTEGER,
        word_count INTEGER,
        views INTEGER,
        last_updated TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Alternative titles - normalized separate table
    await db.execute('''
      CREATE TABLE alternative_titles (
        novel_id TEXT NOT NULL,
        title TEXT NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE,
        PRIMARY KEY (novel_id, title)
      )
    ''');

    // Bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        novel_id TEXT PRIMARY KEY,
        bookmarked_at INTEGER NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE
      )
    ''');

    // Reading history table
    await db.execute('''
      CREATE TABLE reading_history (
        novel_id TEXT PRIMARY KEY,
        last_read_chapter TEXT NOT NULL,
        last_read_at INTEGER NOT NULL,
        FOREIGN KEY (novel_id) REFERENCES novels(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute(
      'CREATE INDEX idx_bookmarks_date ON bookmarks(bookmarked_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_history_date ON reading_history(last_read_at DESC)',
    );

    debugPrint('✅ Novel database tables created');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('📦 Upgrading novel database from v$oldVersion to v$newVersion');
    // Add migration logic here when schema changes
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized || _db == null) {
      await initialize();
    }
  }

  /// Convert absolute URL to relative path (or keep full URLs for cover images)
  String _toRelativePath(String url) {
    if (!url.startsWith('http')) {
      return url; // Already relative
    }

    try {
      final uri = Uri.parse(url);

      // ALWAYS keep full URLs for images that are hosted on external servers
      // This includes:
      // - CDN URLs (docln.net, cloudflare, imgur, etc.)
      // - Other server URLs (ln.hako.vn, docln.sbs, etc.)
      //
      // We do this because:
      // 1. CDN images are externally hosted and can't be rebuilt with server URL
      // 2. Cover images from old servers (ln.hako.vn) don't exist on new servers (docln.sbs)
      // 3. The server may change, but the image URLs should remain stable

      // Only convert to relative path if it's the current novel URL (starts with /truyen/)
      // Cover images and other assets should be kept as full URLs
      if (uri.path.startsWith('/truyen/') || uri.path.startsWith('/novel/')) {
        // This is a novel page URL, can be relative
        return uri.path; // Returns /truyen/123-novel-title format
      }

      // For everything else (cover images, assets, etc.), keep as full URL
      return url;
    } catch (e) {
      debugPrint('⚠️ Error parsing URL: $url');
      return url;
    }
  }

  /// Save or update a novel in the database (internal method with transaction)
  Future<void> _saveNovelInTransaction(
    Transaction txn,
    LightNovel novel,
    int now,
  ) async {
    // Check if novel exists
    final existing = await txn.query(
      'novels',
      where: 'id = ?',
      whereArgs: [novel.id],
    );

    final novelData = {
      'id': novel.id,
      'title': novel.title,
      'relative_url': _toRelativePath(novel.url),
      'relative_cover_url': _toRelativePath(novel.coverUrl),
      'chapters': novel.chapters,
      'latest_chapter': novel.latestChapter,
      'volume_title': novel.volumeTitle,
      'rating': novel.rating,
      'reviews': novel.reviews,
      'word_count': novel.wordCount,
      'views': novel.views,
      'last_updated': novel.lastUpdated,
      'updated_at': now,
    };

    if (existing.isEmpty) {
      // Insert new novel
      novelData['created_at'] = now;
      await txn.insert('novels', novelData);
    } else {
      // Update existing novel
      await txn.update(
        'novels',
        novelData,
        where: 'id = ?',
        whereArgs: [novel.id],
      );
    }

    // Handle alternative titles
    if (novel.alternativeTitles != null &&
        novel.alternativeTitles!.isNotEmpty) {
      // Delete old alternative titles
      await txn.delete(
        'alternative_titles',
        where: 'novel_id = ?',
        whereArgs: [novel.id],
      );

      // Insert new alternative titles
      for (final altTitle in novel.alternativeTitles!) {
        await txn.insert('alternative_titles', {
          'novel_id': novel.id,
          'title': altTitle,
        });
      }
    }
  }

  /// Save or update a novel in the database
  Future<void> saveNovel(LightNovel novel) async {
    await _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db!.transaction((txn) async {
        await _saveNovelInTransaction(txn, novel, now);
      });

      debugPrint('✅ Saved novel: ${novel.title}');
    } catch (e) {
      debugPrint('❌ Error saving novel: $e');
      rethrow;
    }
  }

  /// Get a novel by ID with current server URLs
  Future<LightNovel?> getNovel(String novelId, String currentServer) async {
    await _ensureInitialized();

    try {
      final results = await _db!.query(
        'novels',
        where: 'id = ?',
        whereArgs: [novelId],
      );

      if (results.isEmpty) return null;

      final data = results.first;

      // Get alternative titles
      final altTitlesResults = await _db!.query(
        'alternative_titles',
        where: 'novel_id = ?',
        whereArgs: [novelId],
      );

      final altTitles = altTitlesResults
          .map((row) => row['title'] as String)
          .toList();

      // Build absolute URLs using current server
      final relativeUrl = data['relative_url'] as String;
      final relativeCoverUrl = data['relative_cover_url'] as String?;

      // Build URL based on whether it's relative or absolute
      String buildUrl(String? storedUrl, String fallback) {
        if (storedUrl == null) return fallback;

        // If it's already a full URL (CDN), use as-is
        if (storedUrl.startsWith('http')) {
          return storedUrl;
        }

        // If it's relative, prepend current server
        return '$currentServer$storedUrl';
      }

      return LightNovel(
        id: data['id'] as String,
        title: data['title'] as String,
        url: buildUrl(relativeUrl, '$currentServer/truyen/${data['id']}'),
        coverUrl: buildUrl(relativeCoverUrl, '$currentServer/img/nocover.jpg'),
        chapters: data['chapters'] as int?,
        latestChapter: data['latest_chapter'] as String?,
        volumeTitle: data['volume_title'] as String?,
        rating: data['rating'] as double?,
        reviews: data['reviews'] as int?,
        alternativeTitles: altTitles.isEmpty ? null : altTitles,
        wordCount: data['word_count'] as int?,
        views: data['views'] as int?,
        lastUpdated: data['last_updated'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Error getting novel: $e');
      return null;
    }
  }

  // ==================== BOOKMARKS ====================

  /// Add a novel to bookmarks
  Future<bool> addBookmark(LightNovel novel) async {
    await _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db!.transaction((txn) async {
        // Save the novel first (using transaction)
        await _saveNovelInTransaction(txn, novel, now);

        // Add bookmark
        await txn.insert('bookmarks', {
          'novel_id': novel.id,
          'bookmarked_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

      debugPrint('✅ Added bookmark: ${novel.title}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding bookmark: $e');
      return false;
    }
  }

  /// Remove a novel from bookmarks
  Future<bool> removeBookmark(String novelId) async {
    await _ensureInitialized();

    try {
      final count = await _db!.delete(
        'bookmarks',
        where: 'novel_id = ?',
        whereArgs: [novelId],
      );

      debugPrint('✅ Removed bookmark for novel: $novelId');
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
      return false;
    }
  }

  /// Check if a novel is bookmarked
  Future<bool> isBookmarked(String novelId) async {
    await _ensureInitialized();

    try {
      final results = await _db!.query(
        'bookmarks',
        where: 'novel_id = ?',
        whereArgs: [novelId],
      );

      return results.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking bookmark: $e');
      return false;
    }
  }

  /// Get all bookmarked novels
  Future<List<LightNovel>> getBookmarks(String currentServer) async {
    await _ensureInitialized();

    try {
      final results = await _db!.rawQuery('''
        SELECT n.* FROM novels n
        INNER JOIN bookmarks b ON n.id = b.novel_id
        ORDER BY b.bookmarked_at DESC
      ''');

      final novels = <LightNovel>[];
      for (final row in results) {
        final novel = await getNovel(row['id'] as String, currentServer);
        if (novel != null) {
          novels.add(novel);
        }
      }

      return novels;
    } catch (e) {
      debugPrint('❌ Error getting bookmarks: $e');
      return [];
    }
  }

  // ==================== READING HISTORY ====================

  /// Add or update reading history
  Future<void> addToHistory(LightNovel novel, String chapterTitle) async {
    await _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _db!.transaction((txn) async {
        // Save the novel first (using transaction)
        await _saveNovelInTransaction(txn, novel, now);

        // Add/update history
        await txn.insert('reading_history', {
          'novel_id': novel.id,
          'last_read_chapter': chapterTitle,
          'last_read_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

      debugPrint('✅ Added to history: ${novel.title} - $chapterTitle');
    } catch (e) {
      debugPrint('❌ Error adding to history: $e');
    }
  }

  /// Remove a novel from reading history
  Future<bool> removeFromHistory(String novelId) async {
    await _ensureInitialized();

    try {
      final count = await _db!.delete(
        'reading_history',
        where: 'novel_id = ?',
        whereArgs: [novelId],
      );

      debugPrint('✅ Removed from history: $novelId');
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error removing from history: $e');
      return false;
    }
  }

  /// Clear all reading history
  Future<bool> clearHistory() async {
    await _ensureInitialized();

    try {
      await _db!.delete('reading_history');
      debugPrint('✅ Cleared all reading history');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
      return false;
    }
  }

  /// Get reading history with chapter info
  Future<List<Map<String, dynamic>>> getHistory(String currentServer) async {
    await _ensureInitialized();

    try {
      final results = await _db!.rawQuery('''
        SELECT n.*, h.last_read_chapter, h.last_read_at
        FROM novels n
        INNER JOIN reading_history h ON n.id = h.novel_id
        ORDER BY h.last_read_at DESC
        LIMIT 100
      ''');

      final history = <Map<String, dynamic>>[];
      for (final row in results) {
        final novel = await getNovel(row['id'] as String, currentServer);
        if (novel != null) {
          history.add({
            'novel': novel,
            'lastReadChapter': row['last_read_chapter'] as String,
            'timestamp': DateTime.fromMillisecondsSinceEpoch(
              row['last_read_at'] as int,
            ),
          });
        }
      }

      return history;
    } catch (e) {
      debugPrint('❌ Error getting history: $e');
      return [];
    }
  }

  // ==================== UTILITY ====================

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    await _ensureInitialized();

    try {
      final novelCount =
          Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM novels'),
          ) ??
          0;

      final bookmarkCount =
          Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM bookmarks'),
          ) ??
          0;

      final historyCount =
          Sqflite.firstIntValue(
            await _db!.rawQuery('SELECT COUNT(*) FROM reading_history'),
          ) ??
          0;

      return {
        'novels': novelCount,
        'bookmarks': bookmarkCount,
        'history': historyCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting stats: $e');
      return {};
    }
  }

  /// Clear all data from the database (use with caution!)
  Future<void> clearAllData() async {
    await _ensureInitialized();

    try {
      debugPrint('🗑️ Clearing all novel data from database...');

      await _db!.transaction((txn) async {
        await txn.delete('bookmarks');
        await txn.delete('reading_history');
        await txn.delete('alternative_titles');
        await txn.delete('novels');
      });

      debugPrint('✅ Database cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing database: $e');
      rethrow;
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _initialized = false;
      debugPrint('✅ Novel database closed');
    }
  }
}
