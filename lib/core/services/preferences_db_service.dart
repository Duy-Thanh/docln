import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:docln/core/widgets/custom_toast.dart';

/// A service that manages app preferences using SQLite instead of SharedPreferences
/// to provide more reliable storage and prevent corruption issues.
class PreferencesDbService {
  // Singleton pattern
  static final PreferencesDbService _instance =
      PreferencesDbService._internal();
  factory PreferencesDbService() => _instance;
  PreferencesDbService._internal();

  // Constants
  static const String _dbName = 'preferences.db';
  static const String _backupDbName = 'preferences_backup.db';
  static const int _maxBackupFiles = 10; // Keep 10 rotational backups
  static const Duration _autoBackupInterval = Duration(
    hours: 12,
  ); // Every 12 hours

  // Internal state
  Database? _db;
  bool _initialized = false;
  bool _isRecovering = false;
  Timer? _autoBackupTimer;

  // Cache for faster access
  final Map<String, dynamic> _cache = {};

  // Initialize the database
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      // Check if the database exists
      final exists = await dbFile.exists();

      // Open the database
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          // Create tables
          await db.execute('''
            CREATE TABLE IF NOT EXISTS preferences (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              type TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );

      if (!exists) {
        // Set version info
        await _setMetadata('version', '1.0');
        await _setMetadata(
          'created_at',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Load cache
      await _refreshCache();

      _initialized = true;

      // Start auto-backup
      _startAutoBackup();

      debugPrint('PreferencesDbService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing preferences database: $e');
      // Try to recover if initialization failed
      if (!_isRecovering) {
        await recoverFromBackup();
      }
    }
  }

  // Get the database file path
  Future<String> _getDbPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/$_dbName';
  }

  // Get the backup directory path
  Future<Directory> _getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDocDir.path}/preferences_backup');

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  // Set metadata value
  Future<void> _setMetadata(String key, String value) async {
    try {
      await _db?.execute(
        'INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)',
        [key, value],
      );
    } catch (e) {
      debugPrint('Error setting metadata: $e');
    }
  }

  // Get metadata value
  Future<String?> _getMetadata(String key) async {
    try {
      final result = await _db?.query(
        'metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result != null && result.isNotEmpty) {
        return result.first['value'] as String;
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
    }
    return null;
  }

  // Refresh the cache from database
  Future<void> _refreshCache() async {
    try {
      final result = await _db?.query('preferences');

      _cache.clear();

      if (result != null) {
        for (final row in result) {
          final key = row['key'] as String;
          final value = row['value'] as String;
          final type = row['type'] as String;

          _cache[key] = _convertFromString(value, type);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing cache: $e');
    }
  }

  // Convert a value to its string representation
  Map<String, String> _convertToString(dynamic value) {
    if (value is String) {
      return {'value': value, 'type': 'string'};
    } else if (value is bool) {
      return {'value': value.toString(), 'type': 'bool'};
    } else if (value is int) {
      return {'value': value.toString(), 'type': 'int'};
    } else if (value is double) {
      return {'value': value.toString(), 'type': 'double'};
    } else if (value is List<String>) {
      return {'value': jsonEncode(value), 'type': 'string_list'};
    } else if (value == null) {
      return {'value': '', 'type': 'null'};
    } else {
      // For complex objects, serialize to JSON
      return {'value': jsonEncode(value), 'type': 'json'};
    }
  }

  // Convert a string representation back to its original type
  dynamic _convertFromString(String value, String type) {
    switch (type) {
      case 'string':
        return value;
      case 'bool':
        return value.toLowerCase() == 'true';
      case 'int':
        return int.parse(value);
      case 'double':
        return double.parse(value);
      case 'string_list':
        return (jsonDecode(value) as List).cast<String>();
      case 'json':
        return jsonDecode(value);
      case 'null':
        return null;
      default:
        return value;
    }
  }

  // Set a value in the database
  Future<bool> setValue(String key, dynamic value) async {
    if (!_initialized) await initialize();

    try {
      final conversion = _convertToString(value);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await _db?.execute(
        'INSERT OR REPLACE INTO preferences (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
        [key, conversion['value'], conversion['type'], timestamp],
      );

      // Update cache
      _cache[key] = value;

      return true;
    } catch (e) {
      debugPrint('Error setting value for key $key: $e');
      return false;
    }
  }

  // Get a value from the database (or cache)
  dynamic getValue(String key, {dynamic defaultValue}) {
    // Check cache first for faster access
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    if (!_initialized || _db == null) {
      return defaultValue;
    }

    try {
      return _getValueFromDb(key, defaultValue: defaultValue);
    } catch (e) {
      debugPrint('Error getting value for key $key: $e');
      return defaultValue;
    }
  }

  // Get a value from the database directly
  Future<dynamic> _getValueFromDb(String key, {dynamic defaultValue}) async {
    try {
      final result = await _db?.query(
        'preferences',
        columns: ['value', 'type'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result != null && result.isNotEmpty) {
        final value = result.first['value'] as String;
        final type = result.first['type'] as String;
        final convertedValue = _convertFromString(value, type);

        // Update cache
        _cache[key] = convertedValue;

        return convertedValue;
      }
    } catch (e) {
      debugPrint('Error getting value from db for key $key: $e');
    }

    return defaultValue;
  }

  // CONVENIENCE METHODS

  // String values
  Future<bool> setString(String key, String value) async {
    return await setValue(key, value);
  }

  String getString(String key, {String defaultValue = ''}) {
    final value = getValue(key, defaultValue: defaultValue);
    if (value is String) {
      return value;
    }
    return defaultValue;
  }

  // Bool values
  Future<bool> setBool(String key, bool value) async {
    return await setValue(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final value = getValue(key, defaultValue: defaultValue);
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  // Int values
  Future<bool> setInt(String key, int value) async {
    return await setValue(key, value);
  }

  int getInt(String key, {int defaultValue = 0}) {
    final value = getValue(key, defaultValue: defaultValue);
    if (value is int) {
      return value;
    }
    return defaultValue;
  }

  // Double values
  Future<bool> setDouble(String key, double value) async {
    return await setValue(key, value);
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = getValue(key, defaultValue: defaultValue);
    if (value is double) {
      return value;
    }
    return defaultValue;
  }

  // String list values
  Future<bool> setStringList(String key, List<String> value) async {
    return await setValue(key, value);
  }

  List<String> getStringList(
    String key, {
    List<String> defaultValue = const [],
  }) {
    final value = getValue(key, defaultValue: defaultValue);
    if (value is List<String>) {
      return value;
    } else if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return defaultValue;
  }

  // Remove a value
  Future<bool> removeValue(String key) async {
    if (!_initialized) await initialize();

    try {
      await _db?.delete('preferences', where: 'key = ?', whereArgs: [key]);

      // Remove from cache
      _cache.remove(key);

      return true;
    } catch (e) {
      debugPrint('Error removing value for key $key: $e');
      return false;
    }
  }

  // Clear all values
  Future<bool> clear() async {
    if (!_initialized) await initialize();

    try {
      await _db?.delete('preferences');

      // Clear cache
      _cache.clear();

      return true;
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
      return false;
    }
  }

  // Get all keys
  Set<String> getKeys() {
    if (!_initialized || _db == null) {
      return {};
    }

    return Set<String>.from(_cache.keys);
  }

  // Check if a key exists
  bool containsKey(String key) {
    if (!_initialized || _db == null) {
      return false;
    }

    return _cache.containsKey(key);
  }

  // BACKUP AND RESTORE

  // Start auto-backup timer
  void _startAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(_autoBackupInterval, (_) async {
      await backupDatabase();
    });
  }

  // Create a backup of the database
  Future<bool> backupDatabase() async {
    if (!_initialized) await initialize();

    try {
      // Get paths
      final dbPath = await _getDbPath();
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${backupDir.path}/preferences_$timestamp.db';

      // Create backup
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);

      // Cleanup old backups
      final backups = await getAvailableBackups();
      if (backups.length > _maxBackupFiles) {
        // Sort by date (oldest first)
        backups.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        // Delete oldest backups
        for (var i = 0; i < backups.length - _maxBackupFiles; i++) {
          final backupFile = File(backups[i]['path']);
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
        }
      }

      debugPrint('Database backup created: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Error creating database backup: $e');
      return false;
    }
  }

  // Get available backups
  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final List<Map<String, dynamic>> backups = [];

      final entities = await backupDir.list().toList();
      for (final entity in entities) {
        if (entity is File &&
            entity.path.endsWith('.db') &&
            !entity.path.contains('_corrupted_')) {
          final filename = entity.uri.pathSegments.last;
          final timestampStr = filename.split('_').last.split('.').first;
          final timestamp =
              int.tryParse(timestampStr) ??
              (await entity.lastModified()).millisecondsSinceEpoch;

          backups.add({
            'path': entity.path,
            'filename': filename,
            'timestamp': timestamp,
            'date': DateTime.fromMillisecondsSinceEpoch(timestamp),
            'size': await entity.length(),
          });
        }
      }

      // Sort by date (newest first)
      backups.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      return backups;
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }

  // Restore from a backup
  Future<bool> restoreFromBackup(
    String backupPath,
    BuildContext context,
  ) async {
    if (!_initialized) await initialize();

    try {
      // Close the current database
      await _db?.close();
      _db = null;

      // Get paths
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      final backupFile = File(backupPath);

      // Validate backup file
      if (!await backupFile.exists()) {
        CustomToast.show(context, "Backup file doesn't exist");
        return false;
      }

      // Create a temporary backup of the current database
      if (await dbFile.exists()) {
        final tempBackupPath =
            '${dbPath}_temp_${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(tempBackupPath);
      }

      // Delete current database
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Copy backup to database location
      await backupFile.copy(dbPath);

      // Reopen the database
      _db = await openDatabase(dbPath);

      // Refresh cache
      await _refreshCache();

      CustomToast.show(context, 'Preferences restored successfully');
      return true;
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      CustomToast.show(context, 'Error restoring preferences: $e');
      return false;
    }
  }

  // Create an export file (JSON format)
  Future<String?> createExportFile() async {
    if (!_initialized) await initialize();

    try {
      // Get all preferences
      final result = await _db?.query('preferences');
      final exportData = <String, dynamic>{};

      if (result != null) {
        for (final row in result) {
          final key = row['key'] as String;
          final value = row['value'] as String;
          final type = row['type'] as String;

          exportData[key] = {
            'value': value,
            'type': type,
            'updated_at': row['updated_at'],
          };
        }
      }

      // Create export file
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportPath = '${appDocDir.path}/preferences_export_$timestamp.json';
      final exportFile = File(exportPath);

      // Write JSON to file
      await exportFile.writeAsString(jsonEncode(exportData));

      debugPrint('Preferences exported to: $exportPath');
      return exportPath;
    } catch (e) {
      debugPrint('Error creating export file: $e');
      return null;
    }
  }

  // Import from a file (JSON format)
  Future<bool> importFromFile(String filePath, BuildContext context) async {
    if (!_initialized) await initialize();

    try {
      final importFile = File(filePath);

      // Validate import file
      if (!await importFile.exists()) {
        CustomToast.show(context, "Import file doesn't exist");
        return false;
      }

      // Read JSON from file
      final jsonStr = await importFile.readAsString();
      final importData = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Begin transaction
      await _db?.transaction((txn) async {
        // Import each preference
        for (final entry in importData.entries) {
          final key = entry.key;
          final data = entry.value as Map<String, dynamic>;
          final value = data['value'] as String;
          final type = data['type'] as String;
          final updatedAt = data['updated_at'] as int;

          await txn.execute(
            'INSERT OR REPLACE INTO preferences (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
            [key, value, type, updatedAt],
          );
        }
      });

      // Refresh cache
      await _refreshCache();

      CustomToast.show(context, 'Preferences imported successfully');
      return true;
    } catch (e) {
      debugPrint('Error importing from file: $e');
      CustomToast.show(context, 'Error importing preferences: $e');
      return false;
    }
  }

  // RECOVERY FUNCTIONS

  // Check if the database is corrupted
  Future<bool> isDatabaseCorrupted() async {
    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return false; // Database doesn't exist, so not corrupted
      }

      // Try to open and perform a simple query
      final db = await openDatabase(dbPath);
      await db.query('sqlite_master', limit: 1);
      await db.close();

      return false; // Successfully opened and queried
    } catch (e) {
      debugPrint('Database corruption detected: $e');
      return true; // Failed to open or query
    }
  }

  // Recover from a backup
  Future<bool> recoverFromBackup() async {
    _isRecovering = true;

    try {
      // Get available backups
      final backups = await getAvailableBackups();

      if (backups.isEmpty) {
        debugPrint('No backups available for recovery');
        _isRecovering = false;
        return false;
      }

      // Use the most recent backup
      final latestBackup = backups.first;
      final backupPath = latestBackup['path'];

      // Close the current database if open
      await _db?.close();
      _db = null;

      // Get the database path
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      // Create a corrupted backup for analysis
      if (await dbFile.exists()) {
        final corruptedPath =
            '${dbPath}_corrupted_${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(corruptedPath);
        debugPrint('Preserved corrupted database at: $corruptedPath');
      }

      // Delete corrupted database
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Copy backup to database location
      final backupFile = File(backupPath);
      await backupFile.copy(dbPath);

      // Reopen the database
      _db = await openDatabase(dbPath);

      // Refresh cache
      await _refreshCache();

      _initialized = true;
      _isRecovering = false;

      debugPrint('Database recovered successfully from backup: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Error recovering database: $e');
      _isRecovering = false;
      return false;
    }
  }

  // Create a new empty database if no backups available
  Future<bool> createNewDatabase() async {
    try {
      // Close the current database if open
      await _db?.close();
      _db = null;

      // Get the database path
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      // Create a corrupted backup for analysis
      if (await dbFile.exists()) {
        final corruptedPath =
            '${dbPath}_corrupted_${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(corruptedPath);
      }

      // Delete corrupted database
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Create and open a new database
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS preferences (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              type TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS metadata (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      );

      // Set version info
      await _setMetadata('version', '1.0');
      await _setMetadata(
        'created_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // Refresh cache
      _cache.clear();

      _initialized = true;

      debugPrint('New empty database created successfully');
      return true;
    } catch (e) {
      debugPrint('Error creating new database: $e');
      return false;
    }
  }

  // Static method to repair if needed
  static Future<bool> repairIfNeeded() async {
    final service = PreferencesDbService();

    try {
      if (await service.isDatabaseCorrupted()) {
        debugPrint('Database corruption detected, attempting recovery...');
        return await service.recoverFromBackup();
      }
      return true;
    } catch (e) {
      debugPrint('Error checking/repairing database: $e');
      return false;
    }
  }

  // Cleanup resources
  void dispose() {
    _autoBackupTimer?.cancel();
    _db?.close();
  }
}
