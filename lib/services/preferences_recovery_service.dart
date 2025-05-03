import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../screens/custom_toast.dart';
import 'package:flutter/material.dart';
import 'preferences_service.dart';
import 'preferences_db_service.dart';

class PreferencesRecoveryService {
  // Singleton pattern
  static final PreferencesRecoveryService _instance =
      PreferencesRecoveryService._internal();

  factory PreferencesRecoveryService() => _instance;

  PreferencesRecoveryService._internal();

  // Constants
  static const String _backupFileName = 'preferences_backup.json';
  static const String _sqliteBackupFileName = 'sqlite_preferences_backup.json';
  static const int _maxBackupFiles = 100; // Keep 100 rotational backups
  static const Duration _autoBackupInterval = Duration(
    hours: 6,
  ); // Every 6 hours

  // Internal state
  bool _isRecovering = false;
  Timer? _autoBackupTimer;

  // Services
  final PreferencesService _prefsService = PreferencesService();
  final PreferencesDbService _dbService = PreferencesDbService();

  // File size threshold for corruption detection (2MB)
  static const int _corruptionSizeThreshold = 2 * 1024 * 1024;

  // Initialize the service and start auto-backup
  Future<void> initialize() async {
    await _prefsService.initialize();
    await _checkForCorruption();
    _startAutoBackup();
  }

  // Start the automatic backup timer
  void _startAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(_autoBackupInterval, (_) {
      backupPreferences();
    });
  }

  // Stop the automatic backup timer
  void stopAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
  }

  // Get the path to the app's shared_preferences file
  Future<String?> _getPreferencesFilePath() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final Directory appSupportDir = await getApplicationSupportDirectory();
        return '${appSupportDir.path}/Library/Preferences/com.apple.mobilegestalt.plist';
      } else if (Platform.isAndroid) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String packageName = await _getPackageName();
        return '${appDir.path.split('Android')[0]}Android/data/$packageName/shared_prefs/$packageName.xml';
      }
    } catch (e) {
      debugPrint('Error getting preferences file path: $e');
    }
    return null;
  }

  // Get the path to the app's SQLite preferences database
  Future<String?> _getSQLiteDbPath() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      return '${appDocDir.path}/preferences.db';
    } catch (e) {
      debugPrint('Error getting SQLite database path: $e');
    }
    return null;
  }

  // Get the package name dynamically
  Future<String> _getPackageName() async {
    try {
      const platform = MethodChannel('app.docln/package');
      final String packageName = await platform.invokeMethod('getPackageName');
      return packageName;
    } catch (e) {
      debugPrint('Error getting package name: $e');
      return 'com.docln.app'; // Fallback package name
    }
  }

  // Check if preferences file is corrupted
  Future<bool> _checkForCorruption() async {
    bool legacyCorrupted = await _checkLegacyCorruption();
    bool sqliteCorrupted = await _checkSQLiteCorruption();

    return legacyCorrupted || sqliteCorrupted;
  }

  // Check if legacy SharedPreferences is corrupted
  Future<bool> _checkLegacyCorruption() async {
    try {
      final prefsPath = await _getPreferencesFilePath();
      if (prefsPath == null) return false;

      final prefsFile = File(prefsPath);
      if (!await prefsFile.exists()) return false;

      // Check file size for corruption
      final fileSize = await prefsFile.length();
      if (fileSize > _corruptionSizeThreshold) {
        debugPrint(
          'Legacy preferences file is too large (${fileSize} bytes), likely corrupted',
        );
        return true;
      }

      // For iOS, try to parse the plist file
      if (Platform.isIOS || Platform.isMacOS) {
        try {
          final bytes = await prefsFile.readAsBytes();
          // Simple corruption check - valid plists start with 'bplist'
          if (bytes.length > 6) {
            final header = String.fromCharCodes(bytes.sublist(0, 6));
            if (header != 'bplist') {
              debugPrint('Legacy preferences file has invalid header: $header');
              return true;
            }
          }
        } catch (e) {
          debugPrint('Error reading legacy preferences file: $e');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for legacy corruption: $e');
      return false;
    }
  }

  // Check if SQLite preferences database is corrupted
  Future<bool> _checkSQLiteCorruption() async {
    try {
      final dbPath = await _getSQLiteDbPath();
      if (dbPath == null) return false;

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return false;

      // Check file size for potential corruption (very small or very large)
      final fileSize = await dbFile.length();
      if (fileSize < 1000 || fileSize > _corruptionSizeThreshold) {
        debugPrint(
          'SQLite preferences file size suspicious (${fileSize} bytes), may be corrupted',
        );
        return true;
      }

      // Try to verify database integrity
      try {
        // Let's use the PreferencesDbService's repair method to check
        // This is safer than trying to open and check the database directly here
        bool needsRepair = await PreferencesDbService.repairIfNeeded();
        return needsRepair;
      } catch (e) {
        debugPrint('Error verifying SQLite database integrity: $e');
        return true; // Assume corruption if we can't verify
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for SQLite corruption: $e');
      return false;
    }
  }

  // Recover corrupted preferences
  Future<bool> recoverPreferences(BuildContext context) async {
    if (_isRecovering) return false;

    _isRecovering = true;
    bool success = false;

    try {
      // Check if we need to recover
      final isCorrupted = await _checkForCorruption();
      if (!isCorrupted) {
        _isRecovering = false;
        return true; // No corruption detected
      }

      // Show recovery toast
      if (context.mounted) {
        CustomToast.show(
          context,
          'Attempting to recover preferences...',
          duration: const Duration(seconds: 3),
        );
      }

      // Check if we've migrated to SQLite
      final hasMigrated = _prefsService.getBool(
        '_sqlite_migration_completed',
        defaultValue: false,
      );

      if (hasMigrated) {
        // Recover SQLite preferences
        success = await _recoverSQLitePreferences(context);
      } else {
        // Recover legacy SharedPreferences
        success = await _recoverLegacyPreferences(context);
      }

      if (success && context.mounted) {
        CustomToast.show(
          context,
          'Preferences recovered successfully',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error recovering preferences: $e');
      if (context.mounted) {
        CustomToast.show(
          context,
          'Failed to recover preferences: $e',
          duration: const Duration(seconds: 5),
        );
      }
      success = false;
    } finally {
      _isRecovering = false;
    }

    return success;
  }

  // Recover legacy SharedPreferences
  Future<bool> _recoverLegacyPreferences(BuildContext context) async {
    try {
      // Try to load latest backup
      final backupData = await _loadLatestBackup();
      if (backupData != null) {
        // Clear current preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Restore from backup
        for (final entry in backupData.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is List) {
            if (value.isNotEmpty && value[0] is String) {
              await prefs.setStringList(key, value.cast<String>());
            }
          }
        }

        return true;
      } else {
        // No backup available - create a fresh preferences file
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Set default values
        await prefs.setBool('darkMode', false);
        await prefs.setDouble('textSize', 16.0);
        await prefs.setBool('isNotifications', true);
        await prefs.setString('language', 'English');
        await prefs.setBool('dataSaver', false);

        if (context.mounted) {
          CustomToast.show(
            context,
            'No backup found. Preferences reset to defaults',
            duration: const Duration(seconds: 3),
          );
        }

        return true;
      }
    } catch (e) {
      debugPrint('Error recovering legacy preferences: $e');
      return false;
    }
  }

  // Recover SQLite preferences
  Future<bool> _recoverSQLitePreferences(BuildContext context) async {
    try {
      // Try to restore the database first
      bool restored = await _dbService.recoverFromBackup();

      if (restored) {
        return true;
      }

      // If automatic restore failed, try to use our JSON backups
      final backupData = await _loadLatestSQLiteBackup();
      if (backupData != null) {
        // Clear current preferences
        await _prefsService.clear();

        // Restore from backup
        for (final entry in backupData.entries) {
          final key = entry.key;
          final value = entry.value;

          // Skip internal keys
          if (key.startsWith('_backup_')) continue;

          await _prefsService.setValue(key, value);
        }

        return true;
      } else {
        // No backup available - create a fresh preferences database
        await _prefsService.clear();

        // Set default values
        await _prefsService.setBool('darkMode', false);
        await _prefsService.setDouble('textSize', 16.0);
        await _prefsService.setBool('isNotifications', true);
        await _prefsService.setString('language', 'English');
        await _prefsService.setBool('dataSaver', false);

        if (context.mounted) {
          CustomToast.show(
            context,
            'No SQLite backup found. Preferences reset to defaults',
            duration: const Duration(seconds: 3),
          );
        }

        return true;
      }
    } catch (e) {
      debugPrint('Error recovering SQLite preferences: $e');
      return false;
    }
  }

  // Backup current preferences
  Future<bool> backupPreferences() async {
    try {
      // Check if we've migrated to SQLite
      await _prefsService.initialize();
      final hasMigrated = _prefsService.getBool(
        '_sqlite_migration_completed',
        defaultValue: false,
      );

      if (hasMigrated) {
        // Backup SQLite preferences
        return await _backupSQLitePreferences();
      } else {
        // Backup legacy SharedPreferences
        return await _backupLegacyPreferences();
      }
    } catch (e) {
      debugPrint('Error backing up preferences: $e');
      return false;
    }
  }

  // Backup legacy SharedPreferences
  Future<bool> _backupLegacyPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = prefs.getKeys().fold<Map<String, dynamic>>({}, (
        map,
        key,
      ) {
        map[key] = prefs.get(key);
        return map;
      });

      // Add timestamp
      prefsMap['_backup_timestamp'] = DateTime.now().toIso8601String();

      // Save to file
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(
        '${backupDir.path}/${_backupFileName}_$timestamp.json',
      );

      await backupFile.writeAsString(jsonEncode(prefsMap));

      // Rotate old backups
      await _rotateBackups(_backupFileName);

      debugPrint('Legacy preferences backup completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error backing up legacy preferences: $e');
      return false;
    }
  }

  // Backup SQLite preferences
  Future<bool> _backupSQLitePreferences() async {
    try {
      // First try the native SQLite backup
      final nativeBackupSuccess = await _dbService.backupDatabase();

      // Also create a JSON backup as an additional safety measure
      final allPrefs = _prefsService.getKeys().fold<Map<String, dynamic>>({}, (
        map,
        key,
      ) {
        map[key] = _prefsService.getValue(key);
        return map;
      });

      // Add timestamp
      allPrefs['_backup_timestamp'] = DateTime.now().toIso8601String();
      allPrefs['_backup_version'] = '1.0';

      // Save to file
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(
        '${backupDir.path}/${_sqliteBackupFileName}_$timestamp.json',
      );

      await backupFile.writeAsString(jsonEncode(allPrefs));

      // Rotate old backups
      await _rotateBackups(_sqliteBackupFileName);

      debugPrint('SQLite preferences backup completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error backing up SQLite preferences: $e');
      return false;
    }
  }

  // Rotate backups to keep only the latest N files
  Future<void> _rotateBackups(String filePattern) async {
    try {
      final backupDir = await _getBackupDirectory();
      final files =
          await backupDir.list().where((entity) {
            return entity is File &&
                entity.path.contains(filePattern) &&
                entity.path.endsWith('.json');
          }).toList();

      // Sort by modification time, newest first
      files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      // Delete older backups exceeding the maximum count
      if (files.length > _maxBackupFiles) {
        for (var i = _maxBackupFiles; i < files.length; i++) {
          await (files[i] as File).delete();
        }
      }
    } catch (e) {
      debugPrint('Error rotating backups: $e');
    }
  }

  // Get backup directory
  Future<Directory> _getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDocDir.path}/preferences_backup');

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  // Load the latest backup of legacy SharedPreferences
  Future<Map<String, dynamic>?> _loadLatestBackup() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files =
          await backupDir.list().where((entity) {
            return entity is File &&
                entity.path.contains(_backupFileName) &&
                entity.path.endsWith('.json');
          }).toList();

      if (files.isEmpty) return null;

      // Sort by modification time, newest first
      files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      // Load the latest backup
      final latestBackup = files.first as File;
      final content = await latestBackup.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading latest legacy backup: $e');
      return null;
    }
  }

  // Load the latest backup of SQLite preferences
  Future<Map<String, dynamic>?> _loadLatestSQLiteBackup() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files =
          await backupDir.list().where((entity) {
            return entity is File &&
                entity.path.contains(_sqliteBackupFileName) &&
                entity.path.endsWith('.json');
          }).toList();

      if (files.isEmpty) return null;

      // Sort by modification time, newest first
      files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      // Load the latest backup
      final latestBackup = files.first as File;
      final content = await latestBackup.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading latest SQLite backup: $e');
      return null;
    }
  }

  // Get all available backups with timestamps
  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files =
          await backupDir.list().where((entity) {
            return entity is File &&
                (entity.path.contains(_backupFileName) ||
                    entity.path.contains(_sqliteBackupFileName) ||
                    entity.path.contains('preferences_backup.db')) &&
                (entity.path.endsWith('.json') || entity.path.endsWith('.db'));
          }).toList();

      final results = <Map<String, dynamic>>[];

      for (final entity in files) {
        final file = entity as File;
        final stats = file.statSync();
        final path = file.path;
        final filename = path.split('/').last;

        String type = "unknown";
        DateTime timestamp = stats.modified;
        String backupType = "unknown";

        if (filename.contains(_backupFileName)) {
          type = "legacy";
          backupType = "JSON";
        } else if (filename.contains(_sqliteBackupFileName)) {
          type = "sqlite";
          backupType = "JSON";
        } else if (filename.contains('preferences_backup.db')) {
          type = "sqlite";
          backupType = "SQLite";
        }

        // Try to extract timestamp from filename
        if (filename.contains('_')) {
          final parts = filename.split('_');
          if (parts.length > 0) {
            final lastPart = parts.last.split('.').first;
            if (int.tryParse(lastPart) != null) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(
                int.parse(lastPart),
              );
            }
          }
        }

        try {
          if (type != "sqlite" || backupType != "SQLite") {
            // For JSON files we can read and verify content
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;

            if (data.containsKey('_backup_timestamp')) {
              timestamp = DateTime.parse(data['_backup_timestamp'] as String);
            }
          }
        } catch (e) {
          // Skip invalid backups
          debugPrint('Error reading backup file ${file.path}: $e');
          continue;
        }

        results.add({
          'path': file.path,
          'modified': stats.modified.toIso8601String(),
          'timestamp': timestamp.toIso8601String(),
          'size': stats.size,
          'type': type,
          'format': backupType,
          'filename': filename,
        });
      }

      // Sort by timestamp, newest first
      results.sort((a, b) {
        return (b['timestamp'] as String).compareTo(a['timestamp'] as String);
      });

      return results;
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }

  // Restore from a specific backup file
  Future<bool> restoreFromBackup(
    String backupPath,
    BuildContext context,
  ) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        if (context.mounted) {
          CustomToast.show(context, 'Backup file not found');
        }
        return false;
      }

      // Show restore toast
      if (context.mounted) {
        CustomToast.show(
          context,
          'Restoring preferences...',
          duration: const Duration(seconds: 3),
        );
      }

      bool success = false;
      final path = backupPath.toLowerCase();

      // Determine the backup type
      if (path.endsWith('.db')) {
        // SQLite database backup
        success = await _dbService.restoreFromBackup(backupPath, context);
      } else if (path.contains(_sqliteBackupFileName)) {
        // SQLite JSON backup
        success = await _restoreSQLiteFromJson(backupPath, context);
      } else {
        // Legacy SharedPreferences backup
        success = await _restoreLegacyFromJson(backupPath, context);
      }

      if (success && context.mounted) {
        CustomToast.show(
          context,
          'Preferences restored successfully',
          duration: const Duration(seconds: 3),
        );
      }

      return success;
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      if (context.mounted) {
        CustomToast.show(
          context,
          'Failed to restore preferences: $e',
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }
  }

  // Restore SQLite preferences from JSON backup
  Future<bool> _restoreSQLiteFromJson(
    String backupPath,
    BuildContext context,
  ) async {
    try {
      // Read the backup file
      final content = await File(backupPath).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Clear current preferences (but backup first)
      await _dbService.backupDatabase();
      await _prefsService.clear();

      // Restore from backup
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        // Skip internal keys
        if (key.startsWith('_backup_')) continue;

        await _prefsService.setValue(key, value);
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring SQLite preferences from JSON: $e');
      return false;
    }
  }

  // Restore legacy SharedPreferences from JSON backup
  Future<bool> _restoreLegacyFromJson(
    String backupPath,
    BuildContext context,
  ) async {
    try {
      // Read the backup file
      final content = await File(backupPath).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Clear current preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Restore from backup
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        // Skip internal keys
        if (key.startsWith('_backup_')) continue;

        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is List) {
          if (value.isNotEmpty && value[0] is String) {
            await prefs.setStringList(key, value.cast<String>());
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring legacy preferences from JSON: $e');
      return false;
    }
  }

  // Create an export file that can be shared with other devices
  Future<String?> createExportFile() async {
    try {
      // Check if we've migrated to SQLite
      await _prefsService.initialize();
      final hasMigrated = _prefsService.getBool(
        '_sqlite_migration_completed',
        defaultValue: false,
      );

      if (hasMigrated) {
        // Use SQLite preferences
        return await _dbService.createExportFile();
      } else {
        // Use legacy SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final prefsMap = prefs.getKeys().fold<Map<String, dynamic>>({}, (
          map,
          key,
        ) {
          map[key] = prefs.get(key);
          return map;
        });

        // Add metadata
        prefsMap['_export_timestamp'] = DateTime.now().toIso8601String();
        prefsMap['_export_version'] = '1.0';

        // Save to file
        final appDocDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final exportFile = File(
          '${appDocDir.path}/docln_preferences_export_$timestamp.json',
        );

        await exportFile.writeAsString(jsonEncode(prefsMap));

        return exportFile.path;
      }
    } catch (e) {
      debugPrint('Error creating export file: $e');
      return null;
    }
  }

  // Import preferences from an export file
  Future<bool> importFromFile(String filePath, BuildContext context) async {
    try {
      final importFile = File(filePath);
      if (!await importFile.exists()) {
        if (context.mounted) {
          CustomToast.show(context, 'Import file not found');
        }
        return false;
      }

      final content = await importFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Validate export version
      final exportVersion = data['_export_version'];
      if (exportVersion != '1.0') {
        if (context.mounted) {
          CustomToast.show(
            context,
            'Unsupported export version: $exportVersion',
          );
        }
        return false;
      }

      // Show import toast
      if (context.mounted) {
        CustomToast.show(
          context,
          'Importing preferences...',
          duration: const Duration(seconds: 3),
        );
      }

      // Check if we've migrated to SQLite
      await _prefsService.initialize();
      final hasMigrated = _prefsService.getBool(
        '_sqlite_migration_completed',
        defaultValue: false,
      );

      // Backup current preferences before import
      await backupPreferences();

      if (hasMigrated) {
        // Import to SQLite
        // Clear current preferences
        await _prefsService.clear();

        // Import from file
        for (final entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          // Skip internal keys
          if (key.startsWith('_export_')) continue;

          await _prefsService.setValue(key, value);
        }
      } else {
        // Import to legacy SharedPreferences
        // Clear current preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Import from file
        for (final entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          // Skip internal keys
          if (key.startsWith('_export_')) continue;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is List) {
            if (value.isNotEmpty && value[0] is String) {
              await prefs.setStringList(key, value.cast<String>());
            }
          }
        }
      }

      if (context.mounted) {
        CustomToast.show(
          context,
          'Preferences imported successfully',
          duration: const Duration(seconds: 3),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error importing preferences: $e');
      if (context.mounted) {
        CustomToast.show(
          context,
          'Failed to import preferences: $e',
          duration: const Duration(seconds: 5),
        );
      }
      return false;
    }
  }

  void dispose() {
    stopAutoBackup();
  }
}
