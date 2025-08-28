import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/use_case.dart';
import '../entities/bookmark_entity.dart';
import '../repositories/bookmark_repository.dart';

/// Parameters for adding a bookmark
class AddBookmarkParams extends Params {
  final BookmarkEntity bookmark;
  
  const AddBookmarkParams({required this.bookmark});
  
  @override
  List<Object> get props => [bookmark];
}

/// Use case to add a bookmark
@injectable
class AddBookmark extends UseCase<BookmarkEntity, AddBookmarkParams> {
  final BookmarkRepository repository;
  
  AddBookmark(this.repository);
  
  @override
  Future<Either<Failure, BookmarkEntity>> call(AddBookmarkParams params) async {
    return await repository.addBookmark(params.bookmark);
  }
}