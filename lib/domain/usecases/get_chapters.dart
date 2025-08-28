import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/chapter.dart';
import '../repositories/chapter_repository.dart';

@Injectable()
class GetChaptersUseCase implements UseCase<List<ChapterEntity>, String> {
  final ChapterRepository _repository;

  GetChaptersUseCase(this._repository);

  @override
  Future<Either<Failure, List<ChapterEntity>>> call(String novelId) async {
    return await _repository.getChapters(novelId);
  }
}

@Injectable()
class GetChapterUseCase implements UseCase<ChapterEntity, String> {
  final ChapterRepository _repository;

  GetChapterUseCase(this._repository);

  @override
  Future<Either<Failure, ChapterEntity>> call(String chapterId) async {
    return await _repository.getChapter(chapterId);
  }
}

@Injectable()
class GetChapterContentUseCase implements UseCase<String, String> {
  final ChapterRepository _repository;

  GetChapterContentUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(String chapterId) async {
    return await _repository.getChapterContent(chapterId);
  }
}

@Injectable()
class GetNextChapterUseCase implements UseCase<ChapterEntity?, GetAdjacentChapterParams> {
  final ChapterRepository _repository;

  GetNextChapterUseCase(this._repository);

  @override
  Future<Either<Failure, ChapterEntity?>> call(GetAdjacentChapterParams params) async {
    return await _repository.getNextChapter(params.currentChapterId, params.novelId);
  }
}

@Injectable()
class GetPreviousChapterUseCase implements UseCase<ChapterEntity?, GetAdjacentChapterParams> {
  final ChapterRepository _repository;

  GetPreviousChapterUseCase(this._repository);

  @override
  Future<Either<Failure, ChapterEntity?>> call(GetAdjacentChapterParams params) async {
    return await _repository.getPreviousChapter(params.currentChapterId, params.novelId);
  }
}

class GetAdjacentChapterParams extends Equatable {
  final String currentChapterId;
  final String novelId;

  const GetAdjacentChapterParams({
    required this.currentChapterId,
    required this.novelId,
  });

  @override
  List<Object?> get props => [currentChapterId, novelId];
}
