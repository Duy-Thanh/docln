import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'novel_database_service.dart';
import 'notification_service.dart';
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

  // Android WorkManager MINIMUM is 15 minutes (PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS)
  // Setting lower values will be automatically increased to 15 minutes by Android
  // See: https://developer.android.com/reference/androidx/work/PeriodicWorkRequest
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
      // Cancel any existing task first to ensure clean registration
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
      
      // Register periodic task with proper constraints
      // ExistingWorkPolicy is handled automatically by WorkManager
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        frequency: _checkInterval,
        constraints: Constraints(
          networkType: NetworkType.connected, // Require internet
          requiresBatteryNotLow: false, // Run even on low battery
          requiresCharging: false, // Run even when not charging
          requiresDeviceIdle: false, // Run even when device is active
        ),
        initialDelay: const Duration(minutes: 1), // First check after 1 minute
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      // Save registration status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_checks_enabled', true);
      await prefs.setInt('background_checks_started_at', DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ Periodic novel update checks registered (15-minute interval)');
      debugPrint('⏰ First check will run in ~1 minute, then every ~15 minutes');
      debugPrint('📱 WorkManager will optimize timing based on battery and network');
    } catch (e) {
      debugPrint('❌ Error starting periodic checks: $e');
      rethrow;
    }
  }

  /// Stop periodic background checks
  Future<void> stopPeriodicChecks() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
      
      // Save registration status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_checks_enabled', false);
      
      debugPrint('⏹️ Periodic novel update checks stopped');
    } catch (e) {
      debugPrint('❌ Error stopping periodic checks: $e');
    }
  }

  /// Check if background checks are enabled
  Future<bool> areBackgroundChecksEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('background_checks_enabled') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking background status: $e');
      return false;
    }
  }

  /// Get last background check time
  Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_background_check');
      return timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      debugPrint('❌ Error getting last check time: $e');
      return null;
    }
  }

  /// Check if notifications are enabled for a specific novel
  Future<bool> isNovelNotificationEnabled(String novelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_enabled_$novelId') ?? true;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return true; // Default to enabled
    }
  }

  /// Enable/disable notifications for a specific novel
  Future<void> setNovelNotificationEnabled(String novelId, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled_$novelId', enabled);
      debugPrint(
        '${enabled ? '🔔' : '🔕'} Notifications ${enabled ? 'enabled' : 'disabled'} for novel $novelId',
      );
    } catch (e) {
      debugPrint('❌ Error setting notification status: $e');
    }
  }

  /// Trigger a one-time manual check NOW (for testing/debugging)
  Future<void> triggerManualCheck() async {
    await initialize();

    try {
      debugPrint('⚡ Triggering manual background check...');
      
      // Register a one-time task with no delay
      await Workmanager().registerOneOffTask(
        'manual_check_${DateTime.now().millisecondsSinceEpoch}',
        _taskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        initialDelay: Duration.zero, // Run immediately
      );

      debugPrint('✅ Manual check triggered! Watch logcat for results.');
    } catch (e) {
      debugPrint('❌ Error triggering manual check: $e');
      rethrow;
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
    final startTime = DateTime.now();
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🔄 BACKGROUND TASK STARTED: $task');
    debugPrint('⏰ Time: ${startTime.toString()}');
    debugPrint('═══════════════════════════════════════════════════════');

    try {
      // Save last check time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_background_check', startTime.millisecondsSinceEpoch);

      // Check app version
      await BackgroundNotificationService._checkAppVersion();

      // Get current server URL
      final currentServer =
          prefs.getString('selected_server') ?? 'https://docln.sbs';

      debugPrint('🌐 Server: $currentServer');

      // Initialize database
      final db = NovelDatabaseService();
      await db.initialize();

      // Get all bookmarked novels
      final bookmarks = await db.getBookmarks(currentServer);

      if (bookmarks.isEmpty) {
        debugPrint('ℹ️ No bookmarked novels to check');
        return Future.value(true);
      }

      debugPrint(
        '📚 Checking ${bookmarks.length} bookmarked novels for updates',
      );

      // Test basic connectivity first
      debugPrint('🌐 Testing basic connectivity...');
      try {
        final testResponse = await http.get(Uri.parse('$currentServer/'))
            .timeout(const Duration(seconds: 10));
        debugPrint('   ✅ Server reachable (status: ${testResponse.statusCode})');
      } catch (e) {
        debugPrint('   ❌ Server connectivity test failed: $e');
        debugPrint('   ⚠️ Background tasks may fail due to network issues');
      }

      // Check each bookmarked novel for updates
      for (final novel in bookmarks) {
        try {
          // Check if notifications are enabled for this novel
          final isEnabled =
              prefs.getBool('notification_enabled_${novel.id}') ?? true;

          if (!isEnabled) {
            debugPrint('🔕 Skipping ${novel.title} (notifications disabled)');
            continue;
          }

          await _checkNovelForUpdates(novel, currentServer, db, prefs);
        } catch (e) {
          debugPrint('❌ Error checking novel ${novel.title}: $e');
        }

        // Small delay between requests to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('✅ BACKGROUND TASK COMPLETED');
      debugPrint('⏱️ Duration: ${duration.inSeconds} seconds');
      debugPrint('⏰ Next check: ~15 minutes (Android-controlled)');
      debugPrint('═══════════════════════════════════════════════════════');
      
      return Future.value(true);
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('❌ BACKGROUND TASK FAILED: $e');
      debugPrint('═══════════════════════════════════════════════════════');
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
    debugPrint('   URL: $fullUrl');

    // IMPORTANT: Background tasks run in a separate isolate
    // Complex services (DNS, Proxy) may not work properly in background
    // Use simple direct HTTP connection for reliability
    
    Map<String, dynamic> novelDetails = {};
    
    debugPrint('   🌐 Fetching HTML directly...');
    try {
      final startTime = DateTime.now();
      
      // Simple direct HTTP request with generous timeout
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          final elapsed = DateTime.now().difference(startTime);
          debugPrint('   ❌ HTTP request timed out after ${elapsed.inSeconds}s');
          throw TimeoutException('HTTP timeout after ${elapsed.inSeconds}s');
        },
      );

      final elapsed = DateTime.now().difference(startTime);
      debugPrint('   ✅ Got response (${response.statusCode}) in ${elapsed.inSeconds}s');

      if (response.statusCode != 200) {
        debugPrint('   ❌ Bad status code: ${response.statusCode}');
        return;
      }

      // Parse HTML directly without using CrawlerService
      debugPrint('   📝 Parsing HTML...');
      final document = html_parser.parse(response.body);

      // Extract title
      final titleElement = document.querySelector('.series-name a');
      final title = titleElement?.text.trim() ?? novel.title;

      // Extract cover
      final coverElement = document.querySelector('.series-cover .content.img-in-ratio');
      String? coverUrl = novel.coverUrl;
      if (coverElement != null) {
        final style = coverElement.attributes['style'] ?? '';
        final urlMatch = RegExp(r"url\('([^']+)'\)").firstMatch(style);
        if (urlMatch != null) {
          coverUrl = urlMatch.group(1);
        }
      }

      // Extract chapters
      final chapterElements = document.querySelectorAll('.chapter-name');
      final chapters = <Map<String, dynamic>>[];

      for (var element in chapterElements) {
        final titleElement = element.querySelector('a');
        final linkElement = element.querySelector('a');

        if (titleElement != null && linkElement != null) {
          final chapterTitle = titleElement.text.trim();
          final chapterLink = linkElement.attributes['href'] ?? '';

          chapters.add({
            'title': chapterTitle,
            'url': chapterLink,
          });
        }
      }

      debugPrint('   ✅ Found ${chapters.length} chapters');

      // Extract actual last updated time from the website
      // Look for the latest chapter's time
      String? lastUpdated;
      final firstChapterTime = document.querySelector('.chapter-time');
      if (firstChapterTime != null) {
        lastUpdated = firstChapterTime.text.trim();
      }

      novelDetails = {
        'title': title,
        'cover': coverUrl,
        'chapters': chapters,
        'lastUpdated': lastUpdated, // Use actual time from website, not current time
      };

      debugPrint('   ✅ Parsed successfully');
    } catch (e) {
      debugPrint('   ❌ Failed to fetch/parse: $e');
      return;
    }

    if (novelDetails.isEmpty ||
        novelDetails['title'] == null ||
        (novelDetails['title'] as String).isEmpty) {
      debugPrint('⚠️ No valid novel details returned');
      return;
    }

    // Create updated LightNovel object
    final updatedNovel = LightNovel(
      id: novel.id,
      title: novelDetails['title'] ?? novel.title,
      url: fullUrl,
      coverUrl: novelDetails['cover'] ?? novel.coverUrl,
      chapters: (novelDetails['chapters'] as List?)?.length ?? novel.chapters,
      latestChapter: (novelDetails['chapters'] as List?)?.isNotEmpty == true
          ? (novelDetails['chapters'] as List).first['title']
          : novel.latestChapter,
      lastUpdated: novelDetails['lastUpdated'] ?? novel.lastUpdated,
      rating: novelDetails['rating'] ?? novel.rating,
      reviews: novelDetails['reviews'] ?? novel.reviews,
      views: novelDetails['views'] ?? novel.views,
    );

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
  final oldChapters = lastKnownState['chapters'] as int? ?? 0;
  final newChapters = newNovel.chapters ?? 0;

  if (newChapters > oldChapters) {
    final chaptersAdded = newChapters - oldChapters;
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 1,
      title: '📖 ${newNovel.title}',
      body: chaptersAdded == 1
          ? 'Chapter $newChapters has been released!'
          : '$chaptersAdded new chapters released!',
      payload: 'novel:${newNovel.id}',
    );
  }

  // Check for chapter updates
  if (newNovel.latestChapter != (lastKnownState['latestChapter'] ?? '') &&
      newChapters == oldChapters) {
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
  final newRating = newNovel.rating ?? 0.0;
  final oldReviews = lastKnownState['reviews'] as int? ?? 0;
  final newReviews = newNovel.reviews ?? 0;

  if ((newRating - oldRating).abs() > 0.5 || newReviews - oldReviews > 10) {
    await BackgroundNotificationService._sendNotification(
      id: notificationId + 4,
      title: '⭐ ${newNovel.title}',
      body: 'Rating: ${newRating.toStringAsFixed(1)} ($newReviews reviews)',
      payload: 'novel:${newNovel.id}',
    );
  }
}
