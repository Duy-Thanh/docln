import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/usecases/get_bookmarks.dart';
import '../../domain/usecases/add_bookmark.dart';
import '../../domain/usecases/remove_bookmark.dart';
import '../../../core/utils/use_case.dart';
import '../../domain/entities/bookmark_entity.dart';
import '../../domain/repositories/bookmark_repository.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

/// BLoC for managing bookmark state in DCL2 architecture
@injectable
class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final GetBookmarks _getBookmarks;
  final AddBookmark _addBookmark;
  final RemoveBookmark _removeBookmark;
  final BookmarkRepository _repository;
  
  BookmarkBloc(
    this._getBookmarks,
    this._addBookmark,
    this._removeBookmark,
    this._repository,
  ) : super(BookmarkInitial()) {
    on<LoadBookmarks>(_onLoadBookmarks);
    on<AddBookmarkEvent>(_onAddBookmark);
    on<RemoveBookmarkEvent>(_onRemoveBookmark);
    on<ToggleBookmarkEvent>(_onToggleBookmark);
    on<SearchBookmarks>(_onSearchBookmarks);
    on<CheckBookmarkStatus>(_onCheckBookmarkStatus);
  }
  
  Future<void> _onLoadBookmarks(
    LoadBookmarks event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(BookmarkLoading());
    
    final result = await _getBookmarks(const NoParams());
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (bookmarks) => emit(BookmarkLoaded(bookmarks: bookmarks)),
    );
  }
  
  Future<void> _onAddBookmark(
    AddBookmarkEvent event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _addBookmark(AddBookmarkParams(bookmark: event.bookmark));
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (bookmark) {
        emit(const BookmarkOperationSuccess(
          message: 'Bookmark added successfully',
          isAdded: true,
        ));
        // Reload bookmarks
        add(LoadBookmarks());
      },
    );
  }
  
  Future<void> _onRemoveBookmark(
    RemoveBookmarkEvent event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _removeBookmark(RemoveBookmarkParams(bookmarkId: event.bookmarkId));
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (success) {
        if (success) {
          emit(const BookmarkOperationSuccess(
            message: 'Bookmark removed successfully',
            isAdded: false,
          ));
          // Reload bookmarks
          add(LoadBookmarks());
        } else {
          emit(const BookmarkError(message: 'Failed to remove bookmark'));
        }
      },
    );
  }
  
  Future<void> _onToggleBookmark(
    ToggleBookmarkEvent event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repository.toggleBookmark(event.bookmark);
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (isAdded) {
        emit(BookmarkOperationSuccess(
          message: isAdded ? 'Bookmark added' : 'Bookmark removed',
          isAdded: isAdded,
        ));
        // Reload bookmarks
        add(LoadBookmarks());
      },
    );
  }
  
  Future<void> _onSearchBookmarks(
    SearchBookmarks event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(BookmarkLoading());
    
    final result = await _repository.searchBookmarks(event.query);
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (bookmarks) => emit(BookmarkLoaded(bookmarks: bookmarks)),
    );
  }
  
  Future<void> _onCheckBookmarkStatus(
    CheckBookmarkStatus event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repository.isBookmarked(event.novelId);
    
    result.fold(
      (failure) => emit(BookmarkError(message: failure.message)),
      (isBookmarked) {
        // You can add a specific state for bookmark status check if needed
        // For now, we'll just use the operation success state
        emit(BookmarkOperationSuccess(
          message: isBookmarked ? 'Novel is bookmarked' : 'Novel is not bookmarked',
          isAdded: isBookmarked,
        ));
      },
    );
  }
}