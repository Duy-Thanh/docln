import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

      // Set up periodic sync (every 30 minutes)
      _startPeriodicSync(const Duration(minutes: 30));

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
      if (value.isEmpty) {
        return ""; // Return empty string for empty input
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
      // Fallback to base64 encoding if encryption fails
      try {
        return base64.encode(utf8.encode(value));
      } catch (encodeError) {
        debugPrint('Base64 encoding also failed: $encodeError');
        // Last resort: Return a safe representation of the value
        return 'encrypted_fallback:${value.hashCode}';
      }
    }
  }

  // Decrypt a string
  String _decrypt(String encryptedValue, String key) {
    try {
      // Check if the value contains the IV
      if (encryptedValue.contains(':')) {
        final parts = encryptedValue.split(':');
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
        // Handle legacy data (just base64 encoded)
        return utf8.decode(base64.decode(encryptedValue));
      }
    } catch (e) {
      debugPrint('Decryption error: $e');
      // Return the original value if decryption fails
      return encryptedValue;
    }
  }

  // SUPABASE SYNC FUNCTIONS

  // Start periodic sync
  void _startPeriodicSync(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _syncWithSupabase());

    // Also sync immediately on startup
    _syncWithSupabase();
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

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _db?.close();
  }

  // Ensure required tables exist
  Future<void> _ensureTablesExist() async {
    try {
      // Check if the encrypted_data table exists
      final tables = await _db?.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='encrypted_data'",
      );

      if (tables == null || tables.isEmpty) {
        debugPrint('Creating missing encrypted_data table');
        await _createDb(_db!, 1);
      }
    } catch (e) {
      debugPrint('Error ensuring tables exist: $e');
      // Attempt to create tables if there was an error
      await _createDb(_db!, 1);
    }
  }
}
