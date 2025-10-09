import 'dart:convert';
import 'package:flutter/material.dart';
import 'services/preferences_service.dart';

/// Debug utility to examine backup data and fix migration issues
class DebugMigration {
  static Future<void> printBackupData() async {
    final prefs = PreferencesService();
    await prefs.initialize();

    print('=== BACKUP DATA EXAMINATION ===\n');

    // Get backup bookmarks
    final backupBookmarks = prefs.getString('bookmarked_novels_backup');
    if (backupBookmarks.isNotEmpty) {
      print('📚 BACKUP BOOKMARKS:');
      try {
        final bookmarksList = jsonDecode(backupBookmarks) as List;
        print('   Count: ${bookmarksList.length}');
        
        if (bookmarksList.isNotEmpty) {
          print('\n   First bookmark sample:');
          final firstNovel = bookmarksList[0] as Map<String, dynamic>;
          print('   - Title: ${firstNovel['title']}');
          print('   - URL: ${firstNovel['url']}');
          print('   - Cover URL: ${firstNovel['coverUrl']}');
          print('   - Full JSON:');
          print('     ${jsonEncode(firstNovel)}');
        }
      } catch (e) {
        print('   ERROR parsing: $e');
      }
    } else {
      print('📚 No backup bookmarks found');
    }

    print('\n');

    // Get backup history
    final backupHistory = prefs.getString('reading_history_backup');
    if (backupHistory.isNotEmpty) {
      print('📖 BACKUP HISTORY:');
      try {
        final historyList = jsonDecode(backupHistory) as List;
        print('   Count: ${historyList.length}');
        
        if (historyList.isNotEmpty) {
          print('\n   First history sample:');
          final firstHistory = historyList[0] as Map<String, dynamic>;
          final novel = firstHistory['novel'] as Map<String, dynamic>;
          print('   - Title: ${novel['title']}');
          print('   - URL: ${novel['url']}');
          print('   - Cover URL: ${novel['coverUrl']}');
          print('   - Last Chapter: ${firstHistory['lastReadChapter']}');
          print('   - Full JSON:');
          print('     ${jsonEncode(firstHistory)}');
        }
      } catch (e) {
        print('   ERROR parsing: $e');
      }
    } else {
      print('📖 No backup history found');
    }

    print('\n=== END BACKUP DATA ===');
  }
}
