import 'package:flutter/material.dart';
import 'package:docln/core/models/light_novel.dart';
import 'novel_database_service.dart';
import 'server_management_service.dart';

/// History Service V2
///
/// Uses the new database-based storage instead of JSON serialization.
/// This fixes the critical bug where server changes destroy reading history.
class HistoryServiceV2 extends ChangeNotifier {
  static final HistoryServiceV2 _instance = HistoryServiceV2._internal();
  factory HistoryServiceV2() => _instance;

  HistoryServiceV2._internal();

  final NovelDatabaseService _dbService = NovelDatabaseService();
  final ServerManagementService _serverService = ServerManagementService();

  List<HistoryItemV2> _historyItems = [];

  List<HistoryItemV2> get historyItems => _historyItems;

  Future<void> init() async {
    await _dbService.initialize();
    await _serverService.initialize();
    await loadHistory();
  }

  /// Load history from database
  Future<void> loadHistory() async {
    try {
      final currentServer = _serverService.currentServer;
      final historyData = await _dbService.getHistory(currentServer);

      _historyItems = historyData.map((data) {
        return HistoryItemV2(
          novel: data['novel'] as LightNovel,
          lastReadChapter: data['lastReadChapter'] as String,
          timestamp: data['timestamp'] as DateTime,
        );
      }).toList();

      debugPrint(
        '✅ Loaded ${_historyItems.length} history items from database',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading history: $e');
      _historyItems = [];
      notifyListeners();
    }
  }

  /// Add to history
  Future<void> addToHistory(LightNovel novel, String? chapterTitle) async {
    try {
      await _dbService.addToHistory(novel, chapterTitle ?? 'Unknown Chapter');

      await loadHistory(); // Reload to get updated list
      debugPrint('✅ Added to history: ${novel.title}');
    } catch (e) {
      debugPrint('❌ Error adding to history: $e');
    }
  }

  /// Remove from history
  Future<void> removeFromHistory(String novelId) async {
    try {
      final success = await _dbService.removeFromHistory(novelId);

      if (success) {
        await loadHistory(); // Reload to get updated list
        debugPrint('✅ Removed from history: $novelId');
      }
    } catch (e) {
      debugPrint('❌ Error removing from history: $e');
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      final success = await _dbService.clearHistory();

      if (success) {
        _historyItems = [];
        notifyListeners();
        debugPrint('✅ Cleared all history');
      }
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
    }
  }

  /// Get history count
  int get historyCount => _historyItems.length;

  /// Search history by title
  List<HistoryItemV2> searchHistory(String query) {
    if (query.isEmpty) return _historyItems;

    final lowerQuery = query.toLowerCase();
    return _historyItems.where((item) {
      return item.novel.title.toLowerCase().contains(lowerQuery) ||
          (item.novel.alternativeTitles?.any(
                (alt) => alt.toLowerCase().contains(lowerQuery),
              ) ??
              false);
    }).toList();
  }

  /// Get history item by novel ID
  HistoryItemV2? getHistoryItem(String novelId) {
    try {
      return _historyItems.firstWhere((item) => item.novel.id == novelId);
    } catch (e) {
      return null;
    }
  }

  /// Reload history when server changes
  Future<void> onServerChange() async {
    debugPrint('🔄 Server changed, reloading history...');
    await loadHistory();
  }
}

/// History item model V2
class HistoryItemV2 {
  final LightNovel novel;
  final String lastReadChapter;
  final DateTime timestamp;

  HistoryItemV2({
    required this.novel,
    required this.lastReadChapter,
    required this.timestamp,
  });
}
