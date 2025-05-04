import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'auth_service.dart';

/// A service that manages encrypted SQLite databases and syncs them with Supabase
class EncryptedDbService {
  // Singleton pattern
  static final EncryptedDbService _instance = EncryptedDbService._internal();
  factory EncryptedDbService() => _instance;
  EncryptedDbService._internal();

  // Constants
  static const String _dbName = 'preferences.db';
  static const String _supabaseTable = 'user_databases';
  static const String _encryptionKey = 'encryption_key';

  // Internal state
  Database? _db;
  bool _initialized = false;
  Timer? _syncTimer;

  // Services
  final AuthService _authService = AuthService();

  // Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // First initialize the auth service
      await _authService.initialize();

      // Open the local database
      await _openDatabase();

      // Remove automatic sync at startup
      // _startPeriodicSync(const Duration(minutes: 30));

      _initialized = true;
      debugPrint('EncryptedDbService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing EncryptedDbService: $e');
      rethrow;
    }
  }

  // Open the database with encryption
  Future<void> _openDatabase() async {
    final dbPath = await _getDbPath();
    final encryptionKey = _authService.getUserEncryptionKey();

    // For SqlCipher, you'd use something like:
    // _db = await openDatabase(
    //   dbPath,
    //   password: encryptionKey,
    //   version: 1,
    //   onCreate: _createDb,
    //   onUpgrade: _upgradeDb,
    // );

    // For this implementation, we'll use standard SQLite
    // but encrypt the data before storing it
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );

    // Ensure tables exist even if database wasn't newly created
    await _ensureTablesExist();
  }

  // Create database tables
  Future<void> _createDb(Database db, int version) async {
    // Create tables for encrypted data
    await db.execute('''
      CREATE TABLE IF NOT EXISTS encrypted_data (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Upgrade database if needed
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Add new tables or columns for version 2
    }
  }

  // Get the database file path
  Future<String> _getDbPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/$_dbName';
  }

  // Set a value with encryption
  Future<bool> setValue(String key, dynamic value) async {
    if (!_initialized) await initialize();

    try {
      // Ensure database connection is healthy
      if (!await _ensureDatabaseConnection()) {
        debugPrint('Failed to ensure database connection for setValue');
        return false;
      }

      final encryptionKey = _authService.getUserEncryptionKey();
      final encryptedValue = _encrypt(jsonEncode(value), encryptionKey);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final type = _getTypeString(value);

      await _db?.execute(
        'INSERT OR REPLACE INTO encrypted_data (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
        [key, encryptedValue, type, timestamp],
      );

      return true;
    } catch (e) {
      debugPrint('Error setting encrypted value for key $key: $e');
      return false;
    }
  }

  // Get a value with decryption
  dynamic getValue(String key, {dynamic defaultValue}) async {
    if (!_initialized) await initialize();

    try {
      final result = await _db?.query(
        'encrypted_data',
        columns: ['value', 'type'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result != null && result.isNotEmpty) {
        final encryptedValue = result.first['value'] as String;
        final type = result.first['type'] as String;
        final encryptionKey = _authService.getUserEncryptionKey();

        final decryptedString = _decrypt(encryptedValue, encryptionKey);
        final decodedValue = jsonDecode(decryptedString);

        return decodedValue;
      }
    } catch (e) {
      debugPrint('Error getting encrypted value for key $key: $e');
    }

    return defaultValue;
  }

  // Remove a value
  Future<bool> removeValue(String key) async {
    if (!_initialized) await initialize();

    try {
      await _db?.delete('encrypted_data', where: 'key = ?', whereArgs: [key]);
      return true;
    } catch (e) {
      debugPrint('Error removing encrypted value for key $key: $e');
      return false;
    }
  }

  // Get all keys
  Future<List<String>> getAllKeys() async {
    if (!_initialized) await initialize();

    try {
      final result = await _db?.query('encrypted_data', columns: ['key']);

      if (result != null) {
        return result.map((row) => row['key'] as String).toList();
      }
    } catch (e) {
      debugPrint('Error getting all encrypted keys: $e');
    }

    return [];
  }

  // ENCRYPTION HELPERS

  // Determine the type of a value
  String _getTypeString(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'string';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List<String>) return 'string_list';
    return 'json';
  }

  // Encrypt a string
  String _encrypt(String value, String key) {
    try {
      // Handle potentially problematic values
      if (value == null || value.isEmpty) {
        return ""; // Return empty string for empty input
      }

      // Ensure key is not empty
      if (key == null || key.isEmpty) {
        debugPrint('Warning: Empty encryption key provided, using fallback');
        key = _encryptionKey; // Use default key as fallback
      }

      // Generate a key from the string
      final keyBytes = sha256.convert(utf8.encode(key)).bytes;
      final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));

      // Generate a random IV
      final iv = encrypt.IV.fromSecureRandom(16);

      // Create an encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      // Encrypt the data
      final encrypted = encrypter.encrypt(value, iv: iv);

      // Combine the IV and encrypted data
      final combined = '${iv.base64}:${encrypted.base64}';

      return combined;
    } catch (e) {
      debugPrint('Encryption error: $e');
      debugPrint(
        'Problem value: "${value.length > 20 ? value.substring(0, 20) + "..." : value}"',
      );

      // Fallback to base64 encoding if encryption fails
      try {
        return 'base64:${base64.encode(utf8.encode(value))}';
      } catch (encodeError) {
        debugPrint('Base64 encoding also failed: $encodeError');
        // Last resort: Return a safe representation of the value
        return 'error:${value.hashCode}';
      }
    }
  }

  // Decrypt a string
  String _decrypt(String encryptedValue, String key) {
    try {
      // Handle empty values
      if (encryptedValue == null || encryptedValue.isEmpty) {
        return "";
      }

      // Ensure key is not empty
      if (key == null || key.isEmpty) {
        debugPrint('Warning: Empty decryption key provided, using fallback');
        key = _encryptionKey; // Use default key as fallback
      }

      // Check for fallback encoding formats
      if (encryptedValue.startsWith('base64:')) {
        // Handle base64 fallback format
        final base64Value = encryptedValue.substring(
          7,
        ); // Remove 'base64:' prefix
        return utf8.decode(base64.decode(base64Value));
      } else if (encryptedValue.startsWith('error:')) {
        // Return empty for error values
        debugPrint(
          'Warning: Attempting to decrypt an error value: $encryptedValue',
        );
        return "";
      } else if (encryptedValue.contains(':')) {
        // Normal AES encryption format
        final parts = encryptedValue.split(':');
        if (parts.length != 2) {
          throw Exception('Invalid encrypted value format');
        }

        final ivString = parts[0];
        final dataString = parts[1];

        // Generate a key from the string
        final keyBytes = sha256.convert(utf8.encode(key)).bytes;
        final decryptKey = encrypt.Key(Uint8List.fromList(keyBytes));

        // Create an IV
        final iv = encrypt.IV.fromBase64(ivString);

        // Create a decrypter
        final encrypter = encrypt.Encrypter(encrypt.AES(decryptKey));

        // Decrypt the data
        final decrypted = encrypter.decrypt(
          encrypt.Encrypted.fromBase64(dataString),
          iv: iv,
        );

        return decrypted;
      } else {
        // Try legacy format (just base64 encoded)
        try {
          return utf8.decode(base64.decode(encryptedValue));
        } catch (e) {
          debugPrint('Failed to decode as legacy format: $e');
          return encryptedValue; // Return as-is if all decryption attempts fail
        }
      }
    } catch (e) {
      debugPrint('Decryption error: $e');
      // Return original value if decryption fails completely
      return encryptedValue;
    }
  }

  // SUPABASE SYNC FUNCTIONS

  // Start periodic sync
  void _startPeriodicSync(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _syncWithSupabase());

    // Remove immediate sync on startup
    // _syncWithSupabase();
  }

  // Get the last sync timestamp
  Future<DateTime?> _getLastSyncTimestamp() async {
    return await _authService.getLastSyncTimestamp();
  }

  // Set the last sync timestamp
  Future<void> _setLastSyncTimestamp(DateTime timestamp) async {
    await _authService.setLastSyncTimestamp(timestamp);
  }

  // Sync the local database with Supabase
  Future<void> _syncWithSupabase() async {
    // Only sync if the user is logged in
    if (!_authService.isAuthenticated) {
      debugPrint('Not syncing - user not authenticated');
      return;
    }

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      debugPrint('Starting database sync with Supabase...');

      // Check if the user_databases table exists
      try {
        await supabase.from(_supabaseTable).select().limit(1);
      } catch (e) {
        if (e.toString().contains('relation "user_databases" does not exist')) {
          debugPrint('user_databases table does not exist in Supabase');
          return;
        }
      }

      // Get the last sync timestamp
      final lastSync = await _getLastSyncTimestamp();
      final now = DateTime.now();

      // 1. First, upload local changes to Supabase
      await _uploadChangesToSupabase(user.id, lastSync);

      // 2. Then, download changes from Supabase
      await _downloadChangesFromSupabase(user.id, lastSync);

      // Update the last sync timestamp
      await _setLastSyncTimestamp(now);

      debugPrint('Database sync completed successfully');
    } catch (e) {
      debugPrint('Error syncing with Supabase: $e');
    }
  }

  // Upload local changes to Supabase
  Future<void> _uploadChangesToSupabase(
    String userId,
    DateTime? lastSync,
  ) async {
    Database? prefsDb;
    try {
      debugPrint('==========================================');
      debugPrint('SYNC: Starting data collection for upload');
      debugPrint('==========================================');

      // First, try to get all preferences data from the preferences database
      int itemsToUpload = 0;
      List<Map<String, dynamic>> preferencesData = [];

      try {
        // Get path to preferences database
        final appDocDir = await getApplicationDocumentsDirectory();
        final prefsDbPath = '${appDocDir.path}/preferences.db';

        if (File(prefsDbPath).existsSync()) {
          debugPrint('SYNC: Found preferences database at: $prefsDbPath');
          // Open preferences database
          prefsDb = await openDatabase(prefsDbPath);

          try {
            // Check if preferences table exists
            final tables = await prefsDb.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='preferences'",
            );

            if (tables.isNotEmpty) {
              // Get all preferences
              final prefsList = await prefsDb.query('preferences');
              debugPrint('SYNC: Found ${prefsList.length} preferences to sync');

              if (prefsList.isNotEmpty) {
                debugPrint(
                  'SYNC: Sample preferences keys: ${prefsList.take(5).map((p) => p['key']).join(", ")}...',
                );
              }

              // Convert each preference to encrypted data format
              for (var pref in prefsList) {
                try {
                  final key = pref['key'] as String;
                  final value = pref['value'];
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final encryptionKey = _authService.getUserEncryptionKey();

                  // Convert value to string safely
                  String stringValue;
                  if (value == null) {
                    stringValue = "";
                  } else if (value is String) {
                    stringValue = value;
                  } else {
                    stringValue = value.toString();
                  }

                  final encryptedValue = _encrypt(stringValue, encryptionKey);
                  final type = _getTypeString(value);

                  // Check if the database is still open
                  if (_db == null || !_db!.isOpen) {
                    debugPrint('SYNC: Main database is closed, reopening it');
                    await _openDatabase();

                    if (_db == null || !_db!.isOpen) {
                      throw Exception('Failed to reopen main database');
                    }
                  }

                  // Add to sqlite encrypted_data table
                  await _db?.execute(
                    'INSERT OR REPLACE INTO encrypted_data (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
                    [key, encryptedValue, type, timestamp],
                  );

                  preferencesData.add({
                    'user_id': userId,
                    'data_key': key,
                    'encrypted_value': encryptedValue,
                    'data_type': type,
                    'updated_at':
                        DateTime.fromMillisecondsSinceEpoch(
                          timestamp,
                        ).toIso8601String(),
                  });
                } catch (e) {
                  debugPrint('SYNC: Error processing preference item: $e');
                  // Continue with next item
                }
              }

              itemsToUpload += prefsList.length;
            } else {
              debugPrint('SYNC: No preferences table found in database');
            }
          } finally {
            // Close the preferences database
            if (prefsDb != null && prefsDb.isOpen) {
              await prefsDb.close();
              prefsDb = null;
            }
          }
        } else {
          debugPrint(
            'SYNC: Preferences database file not found at path: $prefsDbPath',
          );
        }
      } catch (e) {
        debugPrint('SYNC: Error fetching preferences data: $e');
        // Close the preferences database if it's still open
        if (prefsDb != null && prefsDb.isOpen) {
          await prefsDb.close();
          prefsDb = null;
        }
        // Continue with normal encrypted_data sync if preferences sync fails
      }

      // Check if the database is still open
      if (_db == null || !_db!.isOpen) {
        debugPrint('SYNC: Main database is closed, reopening it');
        await _openDatabase();

        if (_db == null || !_db!.isOpen) {
          throw Exception('Failed to reopen main database');
        }
      }

      // Now get data from the encrypted_data table
      final query = 'SELECT * FROM encrypted_data';
      final localData = await _db?.rawQuery(query);

      if (localData != null && localData.isNotEmpty) {
        debugPrint(
          'SYNC: Found ${localData.length} entries in encrypted_data table',
        );
        if (localData.isNotEmpty) {
          debugPrint(
            'SYNC: Sample encrypted_data keys: ${localData.take(5).map((item) => item['key']).join(", ")}...',
          );
        }
      } else {
        debugPrint('SYNC: No data found in encrypted_data table');
      }

      if ((localData == null || localData.isEmpty) && preferencesData.isEmpty) {
        debugPrint('SYNC: No local changes to upload');
        return;
      }

      // Add encrypted_data items to the upload
      final List<Map<String, dynamic>> dataToUpload = [...preferencesData];

      // Add encrypted_data items, handling potential errors
      if (localData != null) {
        for (var item in localData) {
          try {
            dataToUpload.add({
              'user_id': userId,
              'data_key': item['key'] as String,
              'encrypted_value': item['value'] as String,
              'data_type': item['type'] as String,
              'updated_at':
                  DateTime.fromMillisecondsSinceEpoch(
                    item['updated_at'] as int,
                  ).toIso8601String(),
            });
          } catch (e) {
            debugPrint(
              'SYNC: Error adding encrypted_data item to upload batch: $e',
            );
            // Continue with next item
          }
        }
      }

      itemsToUpload += localData?.length ?? 0;
      debugPrint(
        'SYNC: Uploading ${dataToUpload.length} total items to Supabase',
      );
      debugPrint(
        'SYNC: Breakdown - ${preferencesData.length} from preferences, ${localData?.length ?? 0} from encrypted_data',
      );

      // Upload in batches to avoid hitting Supabase limits
      const batchSize = 25;
      for (var i = 0; i < dataToUpload.length; i += batchSize) {
        final end =
            (i + batchSize < dataToUpload.length)
                ? i + batchSize
                : dataToUpload.length;

        final batch = dataToUpload.sublist(i, end);
        debugPrint(
          'SYNC: Uploading batch ${i ~/ batchSize + 1} of ${(dataToUpload.length / batchSize).ceil()} (${batch.length} items)',
        );

        // Use upsert to insert or update based on the composite key
        try {
          await supabase
              .from(_supabaseTable)
              .upsert(batch, onConflict: 'user_id,data_key');
          debugPrint('SYNC: Batch upload successful');
        } catch (e) {
          debugPrint('SYNC: Error during upsert operation: $e');
          // Continue trying other batches even if one fails
        }
      }

      debugPrint('SYNC: Successfully uploaded all local changes to Supabase');
    } catch (e) {
      debugPrint('SYNC: Error uploading changes to Supabase: $e');
      // Close the preferences database if it's still open
      if (prefsDb != null && prefsDb.isOpen) {
        await prefsDb.close();
      }
      rethrow;
    }
  }

  // Download changes from Supabase
  Future<int> _downloadChangesFromSupabase(
    String userId,
    DateTime? lastSync,
  ) async {
    try {
      debugPrint('==========================================');
      debugPrint('SYNC: Starting download from Supabase');
      debugPrint('==========================================');

      // Query for remote changes
      final query = supabase
          .from(_supabaseTable)
          .select()
          .eq('user_id', userId);

      debugPrint('SYNC: Fetching data for user ID: $userId');
      if (lastSync != null) {
        debugPrint(
          'SYNC: Filtering for changes since: ${lastSync.toIso8601String()}',
        );
      } else {
        debugPrint('SYNC: No timestamp filter - getting all data');
      }

      // Add timestamp filter if we have a last sync time
      final remoteData =
          lastSync != null
              ? await query
                  .gt('updated_at', lastSync.toIso8601String())
                  .order('updated_at')
              : await query.order('updated_at');

      if (remoteData.isEmpty) {
        debugPrint('SYNC: No remote changes to download');
        return 0;
      }

      debugPrint(
        'SYNC: Downloading ${remoteData.length} changes from Supabase',
      );
      if (remoteData.isNotEmpty) {
        final sampleKeys = remoteData
            .take(5)
            .map((item) => item['data_key'])
            .join(", ");
        debugPrint('SYNC: Sample keys from download: $sampleKeys...');
      }

      // Begin transaction
      debugPrint('SYNC: Starting transaction for database updates');
      await _db?.transaction((txn) async {
        int processed = 0;
        for (final item in remoteData) {
          final key = item['data_key'];
          final encryptedValue = item['encrypted_value'];
          final type = item['data_type'];
          final updatedAtString = item['updated_at'];

          // Parse the ISO8601 datetime to milliseconds since epoch
          final updatedAt =
              DateTime.parse(updatedAtString).millisecondsSinceEpoch;

          // Insert or replace the data
          await txn.execute(
            'INSERT OR REPLACE INTO encrypted_data (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
            [key, encryptedValue, type, updatedAt],
          );

          processed++;
          if (processed % 50 == 0) {
            debugPrint(
              'SYNC: Processed $processed/${remoteData.length} downloaded items',
            );
          }
        }
      });

      debugPrint(
        'SYNC: Successfully downloaded and stored all changes from Supabase',
      );
      return remoteData.length;
    } catch (e) {
      debugPrint('SYNC: Error downloading changes from Supabase: $e');
      rethrow;
    }
  }

  // Force a sync immediately (for use when important data changes)
  Future<Map<String, dynamic>> forceSyncNow() async {
    // Prepare results object
    final results = {
      'success': false,
      'error': null,
      'itemsUploaded': 0,
      'itemsDownloaded': 0,
      'timestamp': DateTime.now(),
    };

    // Only sync if the user is logged in
    if (!_authService.isAuthenticated) {
      results['error'] = 'Not authenticated';
      debugPrint('Not syncing - user not authenticated');
      return results;
    }

    try {
      // Ensure database connection is healthy
      if (!await _ensureDatabaseConnection()) {
        results['error'] = 'Could not establish database connection';
        return results;
      }

      final user = _authService.currentUser;
      if (user == null) {
        results['error'] = 'User is null';
        return results;
      }

      debugPrint('Starting manual database sync with Supabase...');

      // Check if the user_databases table exists
      try {
        await supabase.from(_supabaseTable).select().limit(1);
      } catch (e) {
        if (e.toString().contains('relation "user_databases" does not exist')) {
          debugPrint('user_databases table does not exist in Supabase');
          results['error'] = 'Database table does not exist';
          return results;
        }
      }

      // Get the last sync timestamp
      final lastSync = await _getLastSyncTimestamp();
      final now = DateTime.now();

      // Count the total items in encrypted_data and preferences tables to be synced
      int totalItemsToUpload = 0;

      // Check encrypted_data table
      final encryptedDataCount = Completer<int>();
      _db
          ?.rawQuery('SELECT COUNT(*) as count FROM encrypted_data')
          .then((result) {
            if (result.isNotEmpty) {
              encryptedDataCount.complete(result.first['count'] as int);
            } else {
              encryptedDataCount.complete(0);
            }
          })
          .catchError((e) {
            debugPrint('Error counting encrypted data: $e');
            encryptedDataCount.complete(0);
          });

      // Check preferences database
      int prefsCount = 0;
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final prefsDbPath = '${appDocDir.path}/preferences.db';

        if (File(prefsDbPath).existsSync()) {
          final prefsDb = await openDatabase(prefsDbPath);
          try {
            final tables = await prefsDb.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='preferences'",
            );

            if (tables.isNotEmpty) {
              final countResult = await prefsDb.rawQuery(
                'SELECT COUNT(*) as count FROM preferences',
              );
              if (countResult.isNotEmpty) {
                prefsCount = countResult.first['count'] as int;
              }
            }
          } finally {
            await prefsDb.close();
          }
        }
      } catch (e) {
        debugPrint('Error counting preferences: $e');
      }

      // Get total count
      totalItemsToUpload = await encryptedDataCount.future + prefsCount;

      // Upload local changes to Supabase
      await _uploadChangesToSupabase(
        user.id,
        null,
      ); // Pass null to get all data
      results['itemsUploaded'] = totalItemsToUpload;

      // Download changes from Supabase
      final downloadResult = await _downloadChangesFromSupabase(
        user.id,
        lastSync,
      );
      results['itemsDownloaded'] = downloadResult;

      // Update the last sync timestamp
      await _setLastSyncTimestamp(now);
      results['timestamp'] = now;
      results['success'] = true;

      debugPrint('Manual database sync completed successfully');
      return results;
    } catch (e) {
      debugPrint('Error syncing with Supabase: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  // Enable periodic background sync manually
  Future<bool> enablePeriodicSync({Duration? interval}) async {
    try {
      if (!_authService.isAuthenticated) {
        debugPrint('Cannot enable periodic sync - user not authenticated');
        return false;
      }

      _startPeriodicSync(interval ?? const Duration(minutes: 30));
      debugPrint(
        'Periodic sync enabled with interval: ${interval?.inMinutes ?? 30} minutes',
      );
      return true;
    } catch (e) {
      debugPrint('Error enabling periodic sync: $e');
      return false;
    }
  }

  // Disable periodic background sync
  void disablePeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('Periodic sync disabled');
  }

  // Backup all local data to Supabase, overwriting remote data
  Future<Map<String, dynamic>> backupAllDataToSupabase() async {
    // Prepare results object
    final results = {
      'success': false,
      'error': null,
      'itemsUploaded': 0,
      'timestamp': DateTime.now(),
    };

    // Only backup if the user is logged in
    if (!_authService.isAuthenticated) {
      results['error'] = 'Not authenticated';
      debugPrint('BACKUP: Not backing up - user not authenticated');
      return results;
    }

    try {
      // Ensure database connection is healthy
      if (!await _ensureDatabaseConnection()) {
        results['error'] = 'Could not establish database connection';
        debugPrint('BACKUP: Database connection failed');
        return results;
      }

      final user = _authService.currentUser;
      if (user == null) {
        results['error'] = 'User is null';
        return results;
      }

      debugPrint('BACKUP: Starting full backup to Supabase...');

      // Check if the user_databases table exists
      try {
        await supabase.from(_supabaseTable).select().limit(1);
      } catch (e) {
        if (e.toString().contains('relation "user_databases" does not exist')) {
          debugPrint('BACKUP: user_databases table does not exist in Supabase');
          results['error'] = 'Database table does not exist';
          return results;
        }
      }

      // ======== NEW APPROACH =========
      // 1. First get ALL existing data for this user from Supabase
      debugPrint('BACKUP: Fetching existing data from Supabase...');

      final existingData = await supabase
          .from(_supabaseTable)
          .select('id, user_id, data_key')
          .eq('user_id', user.id);

      // Use dynamic for values to accommodate both String and int types
      final existingKeysMap = <String, dynamic>{};

      if (existingData != null && existingData.isNotEmpty) {
        debugPrint('BACKUP: Found ${existingData.length} existing records');

        // Create a map of data_key -> id for quick lookup
        for (final item in existingData) {
          if (item['data_key'] != null && item['id'] != null) {
            // Store the ID directly, preserving its original type
            existingKeysMap[item['data_key'] as String] = item['id'];

            // Debug the ID type
            if (item['id'] is int) {
              debugPrint(
                'BACKUP: ID for ${item['data_key']} is int: ${item['id']}',
              );
            } else if (item['id'] is String) {
              debugPrint(
                'BACKUP: ID for ${item['data_key']} is String: ${item['id']}',
              );
            } else {
              debugPrint(
                'BACKUP: ID for ${item['data_key']} is ${item['id'].runtimeType}: ${item['id']}',
              );
            }
          }
        }

        // Sample the first few keys for debugging
        final sampleKeys = existingKeysMap.keys.take(3).toList();
        debugPrint('BACKUP: Sample keys in map: $sampleKeys');
        for (final key in sampleKeys) {
          final value = existingKeysMap[key];
          debugPrint(
            'BACKUP: Map entry - key: $key, value: $value (${value.runtimeType})',
          );
        }
      } else {
        debugPrint('BACKUP: No existing data found');
      }

      // 2. Collect all local data to backup
      Database? prefsDb;
      final List<Map<String, dynamic>> allDataToBackup = [];

      try {
        debugPrint('==========================================');
        debugPrint('BACKUP: Collecting all local data for backup');
        debugPrint('==========================================');

        // 2a. First, collect all preferences data from the preferences database
        try {
          // Get path to preferences database
          final appDocDir = await getApplicationDocumentsDirectory();
          final prefsDbPath = '${appDocDir.path}/preferences.db';

          if (File(prefsDbPath).existsSync()) {
            debugPrint('BACKUP: Found preferences database at: $prefsDbPath');
            // Open preferences database
            prefsDb = await openDatabase(prefsDbPath);

            try {
              // Check if preferences table exists
              final tables = await prefsDb.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='preferences'",
              );

              if (tables.isNotEmpty) {
                // Get all preferences
                final prefsList = await prefsDb.query('preferences');
                debugPrint(
                  'BACKUP: Found ${prefsList.length} preferences to backup',
                );

                // Convert each preference to encrypted data format
                for (var pref in prefsList) {
                  try {
                    final key = pref['key'] as String;
                    final value = pref['value'];
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final encryptionKey = _authService.getUserEncryptionKey();

                    // Convert value to string safely
                    String stringValue;
                    if (value == null) {
                      stringValue = "";
                    } else if (value is String) {
                      stringValue = value;
                    } else {
                      stringValue = value.toString();
                    }

                    final encryptedValue = _encrypt(stringValue, encryptionKey);
                    final type = _getTypeString(value);

                    // Create the Supabase record
                    final record = {
                      'user_id': user.id,
                      'data_key': key,
                      'encrypted_value': encryptedValue,
                      'data_type': type,
                      'updated_at':
                          DateTime.fromMillisecondsSinceEpoch(
                            timestamp,
                          ).toIso8601String(),
                    };

                    // If this key already exists in Supabase, add its ID for updating
                    if (existingKeysMap.containsKey(key)) {
                      // Keep ID as an int for database operations
                      record['id'] = existingKeysMap[key];
                    }

                    allDataToBackup.add(record);
                  } catch (e) {
                    debugPrint('BACKUP: Error processing preference item: $e');
                    // Continue with next item
                  }
                }
              } else {
                debugPrint('BACKUP: No preferences table found in database');
              }
            } finally {
              // Close the preferences database
              if (prefsDb != null && prefsDb.isOpen) {
                await prefsDb.close();
                prefsDb = null;
              }
            }
          } else {
            debugPrint(
              'BACKUP: Preferences database file not found at path: $prefsDbPath',
            );
          }
        } catch (e) {
          debugPrint('BACKUP: Error fetching preferences data: $e');
          // Close the preferences database if it's still open
          if (prefsDb != null && prefsDb.isOpen) {
            await prefsDb.close();
            prefsDb = null;
          }
        }

        // 2b. Now get all data from the encrypted_data table
        // Check if the database is still open
        if (_db == null || !_db!.isOpen) {
          debugPrint('BACKUP: Main database is closed, reopening it');
          await _openDatabase();
        }

        final localData = await _db?.query('encrypted_data');

        if (localData != null && localData.isNotEmpty) {
          debugPrint(
            'BACKUP: Found ${localData.length} entries in encrypted_data table',
          );

          // Add encrypted_data items
          for (var item in localData) {
            try {
              final key = item['key'] as String;

              final record = {
                'user_id': user.id,
                'data_key': key,
                'encrypted_value': item['value'] as String,
                'data_type': item['type'] as String,
                'updated_at':
                    DateTime.fromMillisecondsSinceEpoch(
                      item['updated_at'] as int,
                    ).toIso8601String(),
              };

              // If this key already exists in Supabase, add its ID for updating
              if (existingKeysMap.containsKey(key)) {
                // Keep ID as an int for database operations
                record['id'] = existingKeysMap[key];
              }

              allDataToBackup.add(record);
            } catch (e) {
              debugPrint(
                'BACKUP: Error adding encrypted_data item to backup: $e',
              );
              // Continue with next item
            }
          }
        } else {
          debugPrint('BACKUP: No data found in encrypted_data table');
          if (allDataToBackup.isEmpty) {
            debugPrint('BACKUP: No local data found to backup');
            results['error'] = 'No local data to backup';
            return results;
          }
        }

        // 3. Process the backup
        debugPrint(
          'BACKUP: Processing ${allDataToBackup.length} items for backup',
        );

        // 3a. Split into items to update and items to insert
        final itemsToUpdate =
            allDataToBackup.where((item) => item.containsKey('id')).toList();
        final itemsToInsert =
            allDataToBackup.where((item) => !item.containsKey('id')).toList();

        debugPrint(
          'BACKUP: ${itemsToUpdate.length} items to update, ${itemsToInsert.length} items to insert',
        );

        // Track successful operations
        int successfulOperations = 0;
        int failedOperations = 0;

        // 3b. Handle updates
        if (itemsToUpdate.isNotEmpty) {
          debugPrint('BACKUP: Processing updates in small batches');

          // Process updates in small batches
          const updateBatchSize = 5;
          for (var i = 0; i < itemsToUpdate.length; i += updateBatchSize) {
            final end =
                (i + updateBatchSize < itemsToUpdate.length)
                    ? i + updateBatchSize
                    : itemsToUpdate.length;
            final batch = itemsToUpdate.sublist(i, end);

            try {
              // Log batch details for debugging
              debugPrint(
                'BACKUP: Processing update batch with ${batch.length} items',
              );
              for (int i = 0; i < min(2, batch.length); i++) {
                final item = batch[i];
                final id = item['id'];
                debugPrint(
                  'BACKUP: Sample item $i - id: $id (${id.runtimeType}), key: ${item['data_key']}',
                );
              }

              // Process batch as-is without mapping - IDs should already be ints
              await supabase
                  .from(_supabaseTable)
                  .upsert(batch, onConflict: 'id');
              successfulOperations += batch.length;
              debugPrint(
                'BACKUP: Successfully updated batch ${i ~/ updateBatchSize + 1}/${(itemsToUpdate.length / updateBatchSize).ceil()}',
              );
            } catch (e) {
              debugPrint('BACKUP: Error updating batch: $e');
              // Log stack trace for better debugging
              debugPrint('BACKUP: Stack trace: ${StackTrace.current}');
              failedOperations += batch.length;

              // Try individual updates as fallback
              for (final item in batch) {
                try {
                  // ID should already be an int, no need to parse
                  final id = item['id'];

                  await supabase
                      .from(_supabaseTable)
                      .update({
                        'encrypted_value': item['encrypted_value'],
                        'data_type': item['data_type'],
                        'updated_at': item['updated_at'],
                      })
                      .eq('id', id);

                  successfulOperations++;
                  failedOperations--;
                } catch (updateError) {
                  debugPrint(
                    'BACKUP: Error updating individual item: $updateError',
                  );
                }

                await Future.delayed(Duration(milliseconds: 100));
              }
            }

            // Add delay between batches
            if (i + updateBatchSize < itemsToUpdate.length) {
              await Future.delayed(Duration(milliseconds: 300));
            }
          }
        }

        // 3c. Handle inserts
        if (itemsToInsert.isNotEmpty) {
          debugPrint('BACKUP: Processing inserts in small batches');

          // Process inserts in small batches
          const insertBatchSize = 10;
          for (var i = 0; i < itemsToInsert.length; i += insertBatchSize) {
            final end =
                (i + insertBatchSize < itemsToInsert.length)
                    ? i + insertBatchSize
                    : itemsToInsert.length;
            final batch = itemsToInsert.sublist(i, end);

            try {
              // Clean items by removing 'id' field if it somehow exists
              for (final item in batch) {
                item.remove('id');
              }

              await supabase.from(_supabaseTable).insert(batch);
              successfulOperations += batch.length;
              debugPrint(
                'BACKUP: Successfully inserted batch ${i ~/ insertBatchSize + 1}/${(itemsToInsert.length / insertBatchSize).ceil()}',
              );
            } catch (e) {
              debugPrint('BACKUP: Error inserting batch: $e');
              failedOperations += batch.length;

              // Try individual inserts as fallback
              for (final item in batch) {
                try {
                  // First check if it somehow already exists
                  final existing = await supabase
                      .from(_supabaseTable)
                      .select('id')
                      .eq('user_id', item['user_id'])
                      .eq('data_key', item['data_key'])
                      .limit(1);

                  if (existing != null && existing.isNotEmpty) {
                    // Item exists, update it
                    final existingId = existing[0]['id'];
                    await supabase
                        .from(_supabaseTable)
                        .update({
                          'encrypted_value': item['encrypted_value'],
                          'data_type': item['data_type'],
                          'updated_at': item['updated_at'],
                        })
                        .eq('id', existingId);

                    debugPrint(
                      'BACKUP: Successfully updated existing item: ${item['data_key']}',
                    );
                  } else {
                    // Item doesn't exist, insert it
                    await supabase.from(_supabaseTable).insert([item]);
                    debugPrint(
                      'BACKUP: Successfully inserted new item: ${item['data_key']}',
                    );
                  }

                  successfulOperations++;
                  failedOperations--;
                } catch (insertError) {
                  debugPrint(
                    'BACKUP: Error inserting individual item: $insertError',
                  );
                }

                await Future.delayed(Duration(milliseconds: 100));
              }
            }

            // Add delay between batches
            if (i + insertBatchSize < itemsToInsert.length) {
              await Future.delayed(Duration(milliseconds: 300));
            }
          }
        }

        // Update the results with actual statistics
        results['itemsUploaded'] = successfulOperations;
        results['itemsFailed'] = failedOperations;
        results['totalItems'] = allDataToBackup.length;

        // Update the last sync timestamp
        await _setLastSyncTimestamp(DateTime.now());
        results['timestamp'] = DateTime.now();
        results['success'] = successfulOperations > 0;

        debugPrint(
          'BACKUP: Full backup completed with $successfulOperations items uploaded and $failedOperations failed',
        );
        return results;
      } catch (e) {
        debugPrint('BACKUP: Error during backup: $e');
        results['error'] = e.toString();
        return results;
      }
    } catch (e) {
      debugPrint('BACKUP: Error in backup process: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  // Restore all data from Supabase to local database
  Future<Map<String, dynamic>> restoreAllDataFromSupabase() async {
    // Prepare results object
    final results = {
      'success': false,
      'error': null,
      'itemsRestored': 0,
      'timestamp': DateTime.now(),
    };

    // Only restore if the user is logged in
    if (!_authService.isAuthenticated) {
      results['error'] = 'Not authenticated';
      debugPrint('RESTORE: Not restoring - user not authenticated');
      return results;
    }

    try {
      // Ensure database connection is healthy
      if (!await _ensureDatabaseConnection()) {
        results['error'] = 'Could not establish database connection';
        debugPrint('RESTORE: Database connection failed');
        return results;
      }

      final user = _authService.currentUser;
      if (user == null) {
        results['error'] = 'User is null';
        return results;
      }

      debugPrint('RESTORE: Starting full restore from Supabase...');

      // Check if the user_databases table exists
      try {
        await supabase.from(_supabaseTable).select().limit(1);
      } catch (e) {
        if (e.toString().contains('relation "user_databases" does not exist')) {
          debugPrint(
            'RESTORE: user_databases table does not exist in Supabase',
          );
          results['error'] = 'Database table does not exist';
          return results;
        }
      }

      // Check if the database is open
      if (_db == null || !_db!.isOpen) {
        debugPrint('RESTORE: Main database is closed, reopening it');
        await _openDatabase();

        if (_db == null || !_db!.isOpen) {
          results['error'] = 'Failed to open local database';
          return results;
        }
      }

      // Ensure required tables exist
      await _ensureTablesExist();

      // 1. First, clear all existing local data
      debugPrint('RESTORE: Clearing existing local data');
      try {
        await _db?.execute('DELETE FROM encrypted_data');
        debugPrint('RESTORE: Successfully cleared local encrypted_data table');
      } catch (e) {
        debugPrint('RESTORE: Error clearing local data: $e');
        results['error'] = 'Failed to clear local data: ${e.toString()}';
        return results;
      }

      // 2. Fetch all data from Supabase
      debugPrint(
        'RESTORE: Fetching all data from Supabase for user ${user.id}',
      );
      List<Map<String, dynamic>> remoteData = [];

      try {
        remoteData = await supabase
            .from(_supabaseTable)
            .select()
            .eq('user_id', user.id)
            .order('updated_at');

        if (remoteData.isNotEmpty) {
          debugPrint('RESTORE: Found ${remoteData.length} items to restore');

          // Sample the first few records for debugging
          for (int i = 0; i < min(3, remoteData.length); i++) {
            final item = remoteData[i];
            debugPrint(
              'RESTORE: Sample item $i - key: ${item['data_key']}, '
              'type: ${item['data_type']}, id: ${item['id']} (${item['id'].runtimeType})',
            );
          }
        }
      } catch (e) {
        debugPrint('RESTORE: Error fetching data from Supabase: $e');
        results['error'] = 'Failed to fetch data: ${e.toString()}';
        return results;
      }

      if (remoteData.isEmpty) {
        debugPrint('RESTORE: No remote data found to restore');
        results['error'] = 'No remote data found';
        return results;
      }

      // 3. Restore data to local database in batches
      int successfulRestores = 0;
      int errorCount = 0;

      // Process in batches for better performance
      const batchSize = 20;

      for (int i = 0; i < remoteData.length; i += batchSize) {
        final end =
            (i + batchSize < remoteData.length)
                ? i + batchSize
                : remoteData.length;
        final batch = remoteData.sublist(i, end);

        debugPrint(
          'RESTORE: Processing batch ${i ~/ batchSize + 1}/${(remoteData.length / batchSize).ceil()} with ${batch.length} items',
        );

        // Use a transaction for each batch
        try {
          await _db?.transaction((txn) async {
            for (final item in batch) {
              try {
                final key = item['data_key'];
                final encryptedValue = item['encrypted_value'];
                final type = item['data_type'];
                final updatedAtString = item['updated_at'];

                // Skip if any required field is missing
                if (key == null ||
                    encryptedValue == null ||
                    type == null ||
                    updatedAtString == null) {
                  debugPrint(
                    'RESTORE: Skipping item with missing required fields: $item',
                  );
                  continue;
                }

                // Parse the ISO8601 datetime to milliseconds since epoch
                final updatedAt =
                    DateTime.parse(updatedAtString).millisecondsSinceEpoch;

                // Insert the data
                await txn.execute(
                  'INSERT OR REPLACE INTO encrypted_data (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
                  [key, encryptedValue, type, updatedAt],
                );

                successfulRestores++;
              } catch (e) {
                errorCount++;
                debugPrint('RESTORE: Error restoring item: $e');
                // Continue with next item instead of failing the entire restore
              }
            }
          });

          debugPrint(
            'RESTORE: Successfully processed batch ${i ~/ batchSize + 1}',
          );
        } catch (e) {
          debugPrint(
            'RESTORE: Transaction failed for batch ${i ~/ batchSize + 1}: $e',
          );

          // If batch transaction fails, try individual items
          for (final item in batch) {
            try {
              final key = item['data_key'];
              final encryptedValue = item['encrypted_value'];
              final type = item['data_type'];
              final updatedAtString = item['updated_at'];

              if (key == null ||
                  encryptedValue == null ||
                  type == null ||
                  updatedAtString == null) {
                continue;
              }

              final updatedAt =
                  DateTime.parse(updatedAtString).millisecondsSinceEpoch;

              await _db?.execute(
                'INSERT OR REPLACE INTO encrypted_data (key, value, type, updated_at) VALUES (?, ?, ?, ?)',
                [key, encryptedValue, type, updatedAt],
              );

              successfulRestores++;
            } catch (itemError) {
              errorCount++;
              debugPrint(
                'RESTORE: Error restoring individual item: $itemError',
              );
            }
          }
        }

        // Report progress for large restores
        if (i % 100 == 0 && i > 0) {
          debugPrint(
            'RESTORE: Restored $successfulRestores items so far with $errorCount errors',
          );
        }
      }

      debugPrint(
        'RESTORE: Successfully restored $successfulRestores items with $errorCount errors',
      );

      results['itemsRestored'] = successfulRestores;
      results['timestamp'] = DateTime.now();
      results['success'] =
          successfulRestores >
          0; // Consider successful if at least one item was restored

      // Update the last sync timestamp
      await _setLastSyncTimestamp(DateTime.now());

      debugPrint('RESTORE: Full restore completed');
      return results;
    } catch (e) {
      debugPrint('RESTORE: Error in restore process: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _db?.close();
  }

  // Ensure database connection is healthy, reconnect if needed
  Future<bool> _ensureDatabaseConnection() async {
    try {
      // Check if the database is open
      if (_db == null || !_db!.isOpen) {
        debugPrint('Database connection is not open, attempting to reconnect');
        await _openDatabase();

        // Verify connection after reopening
        if (_db == null || !_db!.isOpen) {
          debugPrint('Failed to reconnect to database');
          return false;
        }

        debugPrint('Successfully reconnected to database');
      }

      // Attempt a simple query to verify connection health
      await _db!.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      debugPrint('Error checking database connection: $e');

      // Try to reopen the database
      try {
        // Close the database if it's somehow still open
        if (_db != null && _db!.isOpen) {
          await _db!.close();
        }

        // Reopen the database
        await _openDatabase();
        return _db != null && _db!.isOpen;
      } catch (reopenError) {
        debugPrint('Failed to reopen database after error: $reopenError');
        return false;
      }
    }
  }

  // Ensure required tables exist
  Future<void> _ensureTablesExist() async {
    try {
      debugPrint('Checking if required tables exist...');
      // Check if the encrypted_data table exists
      final encDataTable = await _db?.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='encrypted_data'",
      );

      if (encDataTable == null || encDataTable.isEmpty) {
        debugPrint('Creating missing encrypted_data table');
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS encrypted_data (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            type TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      }

      // Check if the sync_metadata table exists
      final syncMetaTable = await _db?.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_metadata'",
      );

      if (syncMetaTable == null || syncMetaTable.isEmpty) {
        debugPrint('Creating missing sync_metadata table');
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      }

      debugPrint('All required tables exist or have been created');
    } catch (e) {
      debugPrint('Error ensuring tables exist: $e');
      // Try to create all tables from scratch if there was an error
      try {
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS encrypted_data (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            type TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        debugPrint('Created tables after error recovery');
      } catch (retryError) {
        debugPrint('Failed to create tables on retry: $retryError');
      }
    }
  }
}
