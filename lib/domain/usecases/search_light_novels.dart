import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/light_novel.dart';
import '../repositories/light_novel_repository.dart';

@injectable
class SearchLightNovelsUseCase implements UseCase<List<LightNovelEntity>, String> {
  final LightNovelRepository _repository;

  SearchLightNovelsUseCase(this._repository);

  @override
  Future<Either<Failure, List<LightNovelEntity>>> call(String query) async {
    return await _repository.searchLightNovels(query);
  }
}
