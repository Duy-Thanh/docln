import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/chapter.dart';

abstract class ChapterRepository {
  Future<Either<Failure, List<ChapterEntity>>> getChapters(String novelId);

  Future<Either<Failure, ChapterEntity>> getChapter(String id);

  Future<Either<Failure, String>> getChapterContent(String id);

  Future<Either<Failure, void>> saveChapter(ChapterEntity chapter);

  Future<Either<Failure, void>> markChapterAsRead(String id);

  Stream<Either<Failure, List<ChapterEntity>>> watchChapters(String novelId);

  Future<Either<Failure, ChapterEntity?>> getNextChapter(String currentChapterId, String novelId);

  Future<Either<Failure, ChapterEntity?>> getPreviousChapter(String currentChapterId, String novelId);
}
