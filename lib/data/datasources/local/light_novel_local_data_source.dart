import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/exceptions.dart';
import '../../models/light_novel_model.dart';

abstract class LightNovelLocalDataSource {
  Future<List<LightNovelModel>> getCachedLightNovels();
  Future<LightNovelModel?> getCachedLightNovel(String id);
  Future<void> cacheLightNovels(List<LightNovelModel> novels);
  Future<void> cacheLightNovel(LightNovelModel novel);
  Future<void> removeLightNovel(String id);
}

@Injectable(as: LightNovelLocalDataSource)
class LightNovelLocalDataSourceImpl implements LightNovelLocalDataSource {
  final Database _database;

  LightNovelLocalDataSourceImpl(this._database);

  @override
  Future<List<LightNovelModel>> getCachedLightNovels() async {
    try {
      final maps = await _database.query(
        'light_novels',
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => LightNovelModel.fromJson(map)).toList();
    } catch (e) {
      throw CacheException('Failed to get cached light novels: ${e.toString()}');
    }
  }

  @override
  Future<LightNovelModel?> getCachedLightNovel(String id) async {
    try {
      final maps = await _database.query(
        'light_novels',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return LightNovelModel.fromJson(maps.first);
    } catch (e) {
      throw CacheException('Failed to get cached light novel: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheLightNovels(List<LightNovelModel> novels) async {
    final batch = _database.batch();

    for (final novel in novels) {
      batch.insert(
        'light_novels',
        novel.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<void> cacheLightNovel(LightNovelModel novel) async {
    await _database.insert(
      'light_novels',
      novel.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeLightNovel(String id) async {
    await _database.delete(
      'light_novels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
