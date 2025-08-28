import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/light_novel.dart';

abstract class LightNovelRepository {
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, LightNovelEntity>> getLightNovel(String id);

  Future<Either<Failure, void>> saveLightNovel(LightNovelEntity novel);

  Future<Either<Failure, void>> removeLightNovel(String id);

  Future<Either<Failure, List<LightNovelEntity>>> searchLightNovels(
    String query,
  );

  Stream<Either<Failure, List<LightNovelEntity>>> watchLightNovels();
}
