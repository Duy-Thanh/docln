import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/use_case.dart';
import '../entities/bookmark_entity.dart';
import '../repositories/bookmark_repository.dart';

/// Use case to get all bookmarks
@injectable
class GetBookmarks extends UseCase<List<BookmarkEntity>, NoParams> {
  final BookmarkRepository repository;
  
  GetBookmarks(this.repository);
  
  @override
  Future<Either<Failure, List<BookmarkEntity>>> call(NoParams params) async {
    return await repository.getBookmarks();
  }
}