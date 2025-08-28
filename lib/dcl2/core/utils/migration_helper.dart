import 'package:flutter/foundation.dart';
import '../core/utils/feature_flag_service.dart';
import '../core/di/injection_container.dart';
import '../features/bookmarks/data/datasources/bookmark_local_datasource.dart';

/// Helper class to manage DCL1 to DCL2 migration
class Dcl2MigrationHelper {
  static FeatureFlagService? _featureFlagService;
  
  /// Initialize migration helper
  static Future<void> initialize() async {
    try {
      if (isDcl2Available()) {
        _featureFlagService = getIt<FeatureFlagService>();
      }
    } catch (e) {
      debugPrint('Error initializing DCL2 migration helper: $e');
    }
  }
  
  /// Check if DCL2 bookmarks should be used
  static bool shouldUseDcl2Bookmarks() {
    return _featureFlagService?.isDcl2BookmarksEnabled ?? false;
  }
  
  /// Check if DCL2 settings should be used
  static bool shouldUseDcl2Settings() {
    return _featureFlagService?.isDcl2SettingsEnabled ?? false;
  }
  
  /// Check if DCL2 novels should be used
  static bool shouldUseDcl2Novels() {
    return _featureFlagService?.isDcl2NovelsEnabled ?? false;
  }
  
  /// Check if DCL2 reader should be used
  static bool shouldUseDcl2Reader() {
    return _featureFlagService?.isDcl2ReaderEnabled ?? false;
  }
  
  /// Check if DCL2 auth should be used
  static bool shouldUseDcl2Auth() {
    return _featureFlagService?.isDcl2AuthEnabled ?? false;
  }
  
  /// Migrate bookmarks from DCL1 to DCL2
  static Future<void> migrateBookmarks() async {
    try {
      if (isDcl2Available()) {
        final localDataSource = getIt<BookmarkLocalDataSource>();
        await localDataSource.migrateFromDcl1();
        debugPrint('Bookmarks migrated from DCL1 to DCL2');
      }
    } catch (e) {
      debugPrint('Error migrating bookmarks: $e');
    }
  }
  
  /// Enable DCL2 feature for gradual rollout
  static Future<void> enableDcl2Feature(String feature) async {
    try {
      if (_featureFlagService != null) {
        switch (feature) {
          case 'bookmarks':
            await _featureFlagService!.setDcl2BookmarksEnabled(true);
            await migrateBookmarks();
            break;
          case 'settings':
            await _featureFlagService!.setDcl2SettingsEnabled(true);
            break;
          case 'novels':
            await _featureFlagService!.setDcl2NovelsEnabled(true);
            break;
          case 'reader':
            await _featureFlagService!.setDcl2ReaderEnabled(true);
            break;
          case 'auth':
            await _featureFlagService!.setDcl2AuthEnabled(true);
            break;
        }
        debugPrint('DCL2 $feature feature enabled');
      }
    } catch (e) {
      debugPrint('Error enabling DCL2 $feature feature: $e');
    }
  }
  
  /// Get migration status
  static String getMigrationStatus() {
    return _featureFlagService?.migrationStatus ?? 'not_started';
  }
  
  /// Set migration status
  static Future<void> setMigrationStatus(String status) async {
    try {
      if (_featureFlagService != null) {
        await _featureFlagService!.setMigrationStatus(status);
      }
    } catch (e) {
      debugPrint('Error setting migration status: $e');
    }
  }
}