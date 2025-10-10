import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:shared_preferences/shared_preferences.dart';
import 'novel_database_service.dart';
import 'notification_service.dart';
import 'preferences_service.dart';
import '../modules/light_novel.dart';

/// Background service that monitors bookmarked novels for updates
/// Runs even when the app is closed
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  static const String _taskName = 'novel_update_check';
  static const String _uniqueTaskName = 'novel_periodic_check';
  
  // Check interval (15 minutes minimum on Android)
  static const Duration _checkInterval = Duration(minutes: 15);

  bool _initialized = false;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      _initialized = true;
      debugPrint('✅ BackgroundNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing background service: $e');
      rethrow;
    }
  }

  /// Start periodic background checks
  Future<void> startPeriodicChecks() async {
    await initialize();

    try {
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        frequency: _checkInterval,
        constraints: Constraints(
          networkType: NetworkType.connected, // Require internet
        ),
        initialDelay: const Duration(minutes: 1), // First check after 1 minute
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      debugPrint('✅ Periodic novel update checks started');
    } catch (e) {
      debugPrint('❌ Error starting periodic checks: $e');
      rethrow;
    }
  }

  /// Stop periodic background checks
  Future<void> stopPeriodicChecks() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
      debugPrint('⏹️ Periodic novel update checks stopped');
    } catch (e) {
      debugPrint('❌ Error stopping periodic checks: $e');
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('🗑️ All background tasks cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling tasks: $e');
    }
  }

  /// Check if a new app version is available
  static Future<void> _checkAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastKnownVersion = prefs.getString('last_known_app_version') ?? '';
      const currentVersion = '2025.10.10'; // From pubspec.yaml

      if (lastKnownVersion.isNotEmpty && lastKnownVersion != currentVersion) {
        // New version detected
        await _sendNotification(
          id: 999999,
          title: '🎉 App Updated!',
          body: 'DocLN has been updated to version $currentVersion',
          payload: 'app_version_update',
        );
      }

      await prefs.setString('last_known_app_version', currentVersion);
    } catch (e) {
      debugPrint('❌ Error checking app version: $e');
    }
  }

  /// Send a notification
  static Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final notificationService = NotificationService();
      await notificationService.init();

      if (notificationService.isEnabled) {
        await notificationService.showNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }
}

/// Background task callback (must be top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔄 Background task started: $task');

    try {
      // Check app version
      await BackgroundNotificationService._checkAppVersion();

      // Get current server URL
      final prefs = await SharedPreferences.getInstance();
      final currentServer = prefs.getString('selected_server') ?? 'https://docln.net';

      // Initialize database
      final db = NovelDatabaseService();
      await db.initialize();

      // Get all bookmarked novels with notification enabled
      final bookmarks = await db.getAllBookmarks(currentServer);

      if (bookmarks.isEmpty) {
        debugPrint('ℹ️ No bookmarked novels to check');
        return Future.value(true);
      }

      debugPrint('📚 Checking ${bookmarks.length} bookmarked novels for updates');

      // Check each bookmarked novel for updates
      for (final novel in bookmarks) {
        try {
          await _checkNovelForUpdates(novel, currentServer, db, prefs);
        } catch (e) {
          debugPrint('❌ Error checking novel ${novel.title}: $e');
        }

        // Small delay between requests to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));
      }

      debugPrint('✅ Background task completed');
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Check a single novel for updates
Future<void> _checkNovelForUpdates(
  LightNovel novel,
  String currentServer,
  NovelDatabaseService db,
  SharedPreferences prefs,
) async {
  try {
    // Get the full URL
    final fullUrl = novel.url.startsWith('http')
        ? novel.url
        : '$currentServer${novel.url}';

    debugPrint('🔍 Checking: ${novel.title}');

    // Fetch the novel page
    final response = await http.get(Uri.parse(fullUrl)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode != 200) {
      debugPrint('⚠️ Failed to fetch novel: ${response.statusCode}');
      return;
    }

    // Parse the HTML
    final document = parse(response.body);
    final updatedNovel = _parseNovelFromHtml(document, novel.id, fullUrl);

    if (updatedNovel == null) {
      debugPrint('⚠️ Failed to parse novel data');
      return;
    }

    // Get last known state
    final lastKnownKey = 'novel_last_state_${novel.id}';
    final lastKnownStateJson = prefs.getString(lastKnownKey);
    
    Map<String, dynamic>? lastKnownState;
    if (lastKnownStateJson != null) {
      lastKnownState = jsonDecode(lastKnownStateJson) as Map<String, dynamic>;
    }

    // Check for changes and send notifications
    await _compareAndNotify(novel, updatedNovel, lastKnownState);

    // Save updated state
    final newState = {
      'chapters': updatedNovel.chapters,
      'latestChapter': updatedNovel.latestChapter,
      'lastUpdated': updatedNovel.lastUpdated,
      'views': updatedNovel.views,
      'rating': updatedNovel.rating,
      'reviews': updatedNovel.reviews,
    };
    await prefs.setString(lastKnownKey, jsonEncode(newState));

    // Update database
    await db.saveNovel(updatedNovel);

    debugPrint('✅ Updated: ${novel.title}');
  } catch (e) {
    debugPrint('❌ Error checking novel ${novel.title}: $e');
  }
}

/// Parse novel data from HTML
LightNovel? _parseNovelFromHtml(dynamic document, String id, String url) {
  try {
    // This is a simplified parser - adjust based on actual HTML structure
    final title = document.querySelector('h1.novel-title')?.text.trim() ?? '';
    final coverUrl = document.querySelector('img.novel-cover')?.attributes['src'] ?? '';
    final chaptersText = document.querySelector('.chapter-count')?.text.trim() ?? '0';
    final chapters = int.tryParse(chaptersText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final latestChapter = document.querySelector('.latest-chapter')?.text.trim() ?? '';
    final lastUpdated = document.querySelector('.last-updated')?.text.trim() ?? '';

    if (title.isEmpty) return null;

    return LightNovel(
      id: id,
      title: title,
      url: url,
      coverUrl: coverUrl,
      chapters: chapters,
      latestChapter: latestChapter,
      lastUpdated: lastUpdated,
    );
  } catch (e) {
    debugPrint('❌ Error parsing novel HTML: $e');
    return null;
  }
}

/// Compare old and new state and send notifications
Future<void> _compareAndNotify(
  LightNovel oldNovel,
  LightNovel newNovel,
  Map<String, dynamic>? lastKnownState,
) async {
  if (lastKnownState == null) {
    // First time tracking this novel, don't send notifications
    return;
  }

  final notificationId = oldNovel.id.hashCode;

  // Check for new chapters
  if (newNovel.chapters > (lastKnownState['chapters'] ?? 0)) {
    final chaptersAdded = newNovel.chapters - (lastKnownState['chapters'] ?? 0);
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 1,
      title: '📖 ${newNovel.title}',
      body: chaptersAdded == 1
          ? 'Chapter ${newNovel.chapters} has been released!'
          : '$chaptersAdded new chapters released!',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for chapter updates
  if (newNovel.latestChapter != (lastKnownState['latestChapter'] ?? '') &&
      newNovel.chapters == (lastKnownState['chapters'] ?? 0)) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 2,
      title: '✏️ ${newNovel.title}',
      body: 'Chapter "${newNovel.latestChapter}" has been updated!',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for story information updates
  if (newNovel.lastUpdated != (lastKnownState['lastUpdated'] ?? '')) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 3,
      title: '🔄 ${newNovel.title}',
      body: 'Story information has been updated',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for rating/review changes (significant changes only)
  final oldRating = lastKnownState['rating'] as double? ?? 0.0;
  final oldReviews = lastKnownState['reviews'] as int? ?? 0;
  
  if ((newNovel.rating - oldRating).abs() > 0.5 ||
      (newNovel.reviews ?? 0) - oldReviews > 10) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 4,
      title: '⭐ ${newNovel.title}',
      body: 'Rating: ${newNovel.rating?.toStringAsFixed(1)} (${newNovel.reviews} reviews)',
      payload: 'novel:${newNovel.id}',
    );
  }
}
