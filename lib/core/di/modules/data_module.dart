import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../network/api_client.dart';
import '../../network/network_info.dart';

@module
abstract class DataModule {
  @lazySingleton
  Dio get dio => Dio();

  @lazySingleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  ApiClient apiClient(Dio dio, Connectivity connectivity) =>
      ApiClient(dio, connectivity);

  @lazySingleton
  NetworkInfo networkInfo(Connectivity connectivity) =>
      NetworkInfoImpl(connectivity);

  @preResolve
  @lazySingleton
  Future<Database> get database async {
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/docln_dcl2.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create tables for DCL2
        await db.execute('''
          CREATE TABLE light_novels (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cover_url TEXT,
            url TEXT NOT NULL,
            chapters INTEGER,
            latest_chapter TEXT,
            rating REAL,
            reviews INTEGER,
            alternative_titles TEXT,
            word_count INTEGER,
            views INTEGER,
            last_updated TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE chapters (
            id TEXT PRIMARY KEY,
            novel_id TEXT NOT NULL,
            title TEXT NOT NULL,
            url TEXT NOT NULL,
            chapter_number REAL,
            content TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            FOREIGN KEY (novel_id) REFERENCES light_novels (id)
          )
        ''');
      },
    );
  }

  @preResolve
  @lazySingleton
  Future<Box> get hiveBox async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    return await Hive.openBox('docln_dcl2_cache');
  }
}
