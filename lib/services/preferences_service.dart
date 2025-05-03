import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preferences_db_service.dart';

/// A service that provides a unified interface for accessing preferences
/// using both the legacy SharedPreferences and the new SQLite implementation.
///
/// This service handles the migration from SharedPreferences to SQLite and
/// provides the same interface as SharedPreferences for backward compatibility.
class PreferencesService extends ChangeNotifier {
  // Singleton pattern
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  // Services
  final PreferencesDbService _dbService = PreferencesDbService();
  SharedPreferences? _legacyPrefs;

  // Migration status
  bool _initialized = false;
  bool _migrationCompleted = false;

  // Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize the SQLite service
      await _dbService.initialize();

      // Get legacy preferences
      _legacyPrefs = await SharedPreferences.getInstance();

      // Check if migration has been done
      final hasMigrated = _dbService.getBool(
        '_migration_completed',
        defaultValue: false,
      );

      if (!hasMigrated) {
        // Migrate data from SharedPreferences to SQLite
        await _migrateFromSharedPreferences();
      }

      _initialized = true;
      notifyListeners();

      debugPrint('PreferencesService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing preferences service: $e');
      // Fallback to SQLite only
      await _dbService.initialize();
      _initialized = true;
      notifyListeners();
    }
  }

  // Migrate data from SharedPreferences to SQLite
  Future<void> _migrateFromSharedPreferences() async {
    try {
      if (_legacyPrefs == null) return;

      // Get all keys from SharedPreferences
      final keys = _legacyPrefs!.getKeys();

      // Migrate each key
      for (final key in keys) {
        final value = _legacyPrefs!.get(key);

        if (value != null) {
          await _dbService.setValue(key, value);
        }
      }

      // Mark migration as completed
      await _dbService.setBool('_migration_completed', true);
      _migrationCompleted = true;

      debugPrint('Migration from SharedPreferences completed successfully');
    } catch (e) {
      debugPrint('Error migrating from SharedPreferences: $e');
    }
  }

  // Public method to migrate from SharedPreferences to SQLite
  Future<int> migrateToSQLite() async {
    if (!_initialized) await initialize();
    if (_migrationCompleted) return 0; // Already migrated

    try {
      if (_legacyPrefs == null) {
        _legacyPrefs = await SharedPreferences.getInstance();
      }

      // Get all keys from SharedPreferences
      final keys = _legacyPrefs!.getKeys();
      int migrated = 0;

      // Migrate each key
      for (final key in keys) {
        final value = _legacyPrefs!.get(key);

        if (value != null) {
          await _dbService.setValue(key, value);
          migrated++;
        }
      }

      // Mark migration as completed
      await _dbService.setBool('_migration_completed', true);
      _migrationCompleted = true;

      debugPrint(
        'Migrated $migrated preferences from SharedPreferences to SQLite',
      );
      return migrated;
    } catch (e) {
      debugPrint('Error in migrateToSQLite: $e');
      return 0;
    }
  }

  // CONVENIENCE METHODS

  // String values
  Future<bool> setString(String key, String value) async {
    if (!_initialized) await initialize();
    return await _dbService.setString(key, value);
  }

  String getString(String key, {String defaultValue = ''}) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.getString(key) ?? defaultValue;
    }
    return _dbService.getString(key, defaultValue: defaultValue);
  }

  // Bool values
  Future<bool> setBool(String key, bool value) async {
    if (!_initialized) await initialize();
    return await _dbService.setBool(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.getBool(key) ?? defaultValue;
    }
    return _dbService.getBool(key, defaultValue: defaultValue);
  }

  // Int values
  Future<bool> setInt(String key, int value) async {
    if (!_initialized) await initialize();
    return await _dbService.setInt(key, value);
  }

  int getInt(String key, {int defaultValue = 0}) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.getInt(key) ?? defaultValue;
    }
    return _dbService.getInt(key, defaultValue: defaultValue);
  }

  // Double values
  Future<bool> setDouble(String key, double value) async {
    if (!_initialized) await initialize();
    return await _dbService.setDouble(key, value);
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.getDouble(key) ?? defaultValue;
    }
    return _dbService.getDouble(key, defaultValue: defaultValue);
  }

  // String list values
  Future<bool> setStringList(String key, List<String> value) async {
    if (!_initialized) await initialize();
    return await _dbService.setStringList(key, value);
  }

  List<String> getStringList(
    String key, {
    List<String> defaultValue = const [],
  }) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.getStringList(key) ?? defaultValue;
    }
    return _dbService.getStringList(key, defaultValue: defaultValue);
  }

  // Generic value
  Future<bool> setValue(String key, dynamic value) async {
    if (!_initialized) await initialize();
    return await _dbService.setValue(key, value);
  }

  dynamic getValue(String key, {dynamic defaultValue}) {
    if (!_initialized) {
      // Return from legacy prefs if available
      return _legacyPrefs?.get(key) ?? defaultValue;
    }
    return _dbService.getValue(key, defaultValue: defaultValue);
  }

  // Remove a value
  Future<bool> remove(String key) async {
    if (!_initialized) await initialize();

    // Remove from both services to ensure consistency
    if (_legacyPrefs != null) {
      await _legacyPrefs!.remove(key);
    }

    return await _dbService.removeValue(key);
  }

  // Clear all values
  Future<bool> clear() async {
    if (!_initialized) await initialize();

    // Clear both services to ensure consistency
    if (_legacyPrefs != null) {
      await _legacyPrefs!.clear();
    }

    return await _dbService.clear();
  }

  // Get all keys
  Set<String> getKeys() {
    if (!_initialized) {
      return _legacyPrefs?.getKeys() ?? {};
    }

    return Set<String>.from(_dbService.getKeys());
  }

  // Check if a key exists
  bool containsKey(String key) {
    if (!_initialized) {
      return _legacyPrefs?.containsKey(key) ?? false;
    }

    return _dbService.containsKey(key);
  }

  // Backup and restore

  // Create a backup
  Future<bool> backup() async {
    if (!_initialized) await initialize();
    return await _dbService.backupDatabase();
  }

  // Get available backups
  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    if (!_initialized) await initialize();
    return await _dbService.getAvailableBackups();
  }

  // Restore from a specific backup
  Future<bool> restoreFromBackup(
    String backupPath,
    BuildContext context,
  ) async {
    if (!_initialized) await initialize();
    return await _dbService.restoreFromBackup(backupPath, context);
  }

  // Create an export file
  Future<String?> createExportFile() async {
    if (!_initialized) await initialize();
    return await _dbService.createExportFile();
  }

  // Import from a file
  Future<bool> importFromFile(String filePath, BuildContext context) async {
    if (!_initialized) await initialize();
    return await _dbService.importFromFile(filePath, context);
  }

  // Cleanup resources
  void dispose() {
    _dbService.dispose();
  }

  // Static method to repair if needed (for use in main.dart)
  static Future<bool> repairIfNeeded() async {
    return await PreferencesDbService.repairIfNeeded();
  }
}
