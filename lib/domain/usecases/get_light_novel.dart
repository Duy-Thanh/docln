import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/light_novel.dart';
import '../repositories/light_novel_repository.dart';

@injectable
class GetLightNovelUseCase implements UseCase<LightNovelEntity, String> {
  final LightNovelRepository _repository;

  GetLightNovelUseCase(this._repository);

  @override
  Future<Either<Failure, LightNovelEntity>> call(String id) async {
    return await _repository.getLightNovel(id);
  }
}
