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

class PreferencesRecoveryService {
  // Singleton pattern
  static final PreferencesRecoveryService _instance =
      PreferencesRecoveryService._internal();

  factory PreferencesRecoveryService() => _instance;

  PreferencesRecoveryService._internal();

  // Constants
  static const String _backupFileName = 'preferences_backup.json';
  static const int _maxBackupFiles = 5; // Keep 5 rotational backups
  static const Duration _autoBackupInterval = Duration(
    hours: 6,
  ); // Every 6 hours

  // Internal state
  bool _isRecovering = false;
  Timer? _autoBackupTimer;

  // File size threshold for corruption detection (2MB)
  static const int _corruptionSizeThreshold = 2 * 1024 * 1024;

  // Initialize the service and start auto-backup
  Future<void> initialize() async {
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
    try {
      final prefsPath = await _getPreferencesFilePath();
      if (prefsPath == null) return false;

      final prefsFile = File(prefsPath);
      if (!await prefsFile.exists()) return false;

      // Check file size for corruption
      final fileSize = await prefsFile.length();
      if (fileSize > _corruptionSizeThreshold) {
        debugPrint(
          'Preferences file is too large (${fileSize} bytes), likely corrupted',
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
              debugPrint('Preferences file has invalid header: $header');
              return true;
            }
          }
        } catch (e) {
          debugPrint('Error reading preferences file: $e');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for corruption: $e');
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

        success = true;
        if (context.mounted) {
          CustomToast.show(
            context,
            'Preferences recovered successfully',
            duration: const Duration(seconds: 3),
          );
        }
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

        success = true;
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

  // Backup current preferences
  Future<bool> backupPreferences() async {
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
      await _rotateBackups();

      debugPrint('Preferences backup completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error backing up preferences: $e');
      return false;
    }
  }

  // Rotate backups to keep only the latest N files
  Future<void> _rotateBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files =
          await backupDir.list().where((entity) {
            return entity is File &&
                entity.path.contains(_backupFileName) &&
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

  // Load the latest backup
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
      debugPrint('Error loading latest backup: $e');
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
                entity.path.contains(_backupFileName) &&
                entity.path.endsWith('.json');
          }).toList();

      final results = <Map<String, dynamic>>[];

      for (final entity in files) {
        final file = entity as File;
        final stats = file.statSync();

        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;

          results.add({
            'path': file.path,
            'modified': stats.modified.toIso8601String(),
            'size': stats.size,
            'timestamp':
                data['_backup_timestamp'] ?? stats.modified.toIso8601String(),
          });
        } catch (e) {
          // Skip invalid backups
          debugPrint('Error reading backup file ${file.path}: $e');
        }
      }

      // Sort by modification time, newest first
      results.sort((a, b) {
        return (b['modified'] as String).compareTo(a['modified'] as String);
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

      final content = await backupFile.readAsString();
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

      if (context.mounted) {
        CustomToast.show(
          context,
          'Preferences restored successfully',
          duration: const Duration(seconds: 3),
        );
      }

      return true;
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

  // Create an export file that can be shared with other devices
  Future<String?> createExportFile() async {
    try {
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

      // Backup current preferences before import
      await backupPreferences();

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

  // Function to repair corrupted preferences (for use in main.dart on startup)
  static Future<bool> repairIfNeeded() async {
    try {
      final service = PreferencesRecoveryService();
      final isCorrupted = await service._checkForCorruption();

      if (isCorrupted) {
        debugPrint('Corrupted preferences detected, attempting repair');

        // Try to load latest backup
        final backupData = await service._loadLatestBackup();
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

          debugPrint('Preferences repaired successfully from backup');
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

          debugPrint('No backup found. Preferences reset to defaults');
          return true;
        }
      }

      return true; // No corruption detected
    } catch (e) {
      debugPrint('Error repairing preferences: $e');
      return false;
    }
  }

  void dispose() {
    stopAutoBackup();
  }
}
