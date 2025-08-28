import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/use_case.dart';
import '../repositories/bookmark_repository.dart';

/// Parameters for removing a bookmark
class RemoveBookmarkParams extends Params {
  final String bookmarkId;
  
  const RemoveBookmarkParams({required this.bookmarkId});
  
  @override
  List<Object> get props => [bookmarkId];
}

/// Use case to remove a bookmark
@injectable
class RemoveBookmark extends UseCase<bool, RemoveBookmarkParams> {
  final BookmarkRepository repository;
  
  RemoveBookmark(this.repository);
  
  @override
  Future<Either<Failure, bool>> call(RemoveBookmarkParams params) async {
    return await repository.removeBookmark(params.bookmarkId);
  }
}