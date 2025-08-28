import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/light_novel.dart';
import '../repositories/light_novel_repository.dart';

class GetLightNovelsParams extends Equatable {
  final int page;
  final int limit;

  const GetLightNovelsParams({
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [page, limit];
}

@injectable
class GetLightNovelsUseCase
    implements UseCase<List<LightNovelEntity>, GetLightNovelsParams> {
  final LightNovelRepository _repository;

  GetLightNovelsUseCase(this._repository);

  @override
  Future<Either<Failure, List<LightNovelEntity>>> call(
    GetLightNovelsParams params,
  ) async {
    return await _repository.getLightNovels(
      page: params.page,
      limit: params.limit,
    );
  }
}
