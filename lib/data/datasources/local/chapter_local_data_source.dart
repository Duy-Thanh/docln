import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/exceptions.dart';
import '../../models/chapter_model.dart';

abstract class ChapterLocalDataSource {
  Future<List<ChapterModel>> getCachedChapters(String novelId);
  Future<ChapterModel?> getCachedChapter(String id);
  Future<String?> getCachedChapterContent(String id);
  Future<void> cacheChapters(List<ChapterModel> chapters);
  Future<void> cacheChapter(ChapterModel chapter);
  Future<void> cacheChapterContent(String id, String content);
  Future<void> markChapterAsRead(String id);
}

@Injectable(as: ChapterLocalDataSource)
class ChapterLocalDataSourceImpl implements ChapterLocalDataSource {
  final Database _database;

  ChapterLocalDataSourceImpl(this._database);

  @override
  Future<List<ChapterModel>> getCachedChapters(String novelId) async {
    try {
      final maps = await _database.query(
        'chapters',
        where: 'novel_id = ?',
        whereArgs: [novelId],
        orderBy: 'chapter_number ASC',
      );

      return maps.map((map) => ChapterModel.fromJson(map)).toList();
    } catch (e) {
      throw CacheException('Failed to get cached chapters: ${e.toString()}');
    }
  }

  @override
  Future<ChapterModel?> getCachedChapter(String id) async {
    try {
      final maps = await _database.query(
        'chapters',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return ChapterModel.fromJson(maps.first);
    } catch (e) {
      throw CacheException('Failed to get cached chapter: ${e.toString()}');
    }
  }

  @override
  Future<String?> getCachedChapterContent(String id) async {
    try {
      final maps = await _database.query(
        'chapters',
        columns: ['content'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty || maps.first['content'] == null) return null;
      return maps.first['content'] as String;
    } catch (e) {
      throw CacheException('Failed to get cached chapter content: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheChapters(List<ChapterModel> chapters) async {
    final batch = _database.batch();

    for (final chapter in chapters) {
      batch.insert(
        'chapters',
        chapter.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<void> cacheChapter(ChapterModel chapter) async {
    await _database.insert(
      'chapters',
      chapter.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> cacheChapterContent(String id, String content) async {
    await _database.update(
      'chapters',
      {'content': content, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markChapterAsRead(String id) async {
    await _database.update(
      'chapters',
      {'is_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
