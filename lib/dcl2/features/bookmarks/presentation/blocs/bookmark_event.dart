import 'package:equatable/equatable.dart';
import '../../domain/entities/bookmark_entity.dart';

/// Base event for bookmark BLoC
abstract class BookmarkEvent extends Equatable {
  const BookmarkEvent();
  
  @override
  List<Object?> get props => [];
}

/// Load all bookmarks
class LoadBookmarks extends BookmarkEvent {}

/// Add a bookmark
class AddBookmarkEvent extends BookmarkEvent {
  final BookmarkEntity bookmark;
  
  const AddBookmarkEvent({required this.bookmark});
  
  @override
  List<Object> get props => [bookmark];
}

/// Remove a bookmark
class RemoveBookmarkEvent extends BookmarkEvent {
  final String bookmarkId;
  
  const RemoveBookmarkEvent({required this.bookmarkId});
  
  @override
  List<Object> get props => [bookmarkId];
}

/// Toggle bookmark status
class ToggleBookmarkEvent extends BookmarkEvent {
  final BookmarkEntity bookmark;
  
  const ToggleBookmarkEvent({required this.bookmark});
  
  @override
  List<Object> get props => [bookmark];
}

/// Search bookmarks
class SearchBookmarks extends BookmarkEvent {
  final String query;
  
  const SearchBookmarks({required this.query});
  
  @override
  List<Object> get props => [query];
}

/// Check if novel is bookmarked
class CheckBookmarkStatus extends BookmarkEvent {
  final String novelId;
  
  const CheckBookmarkStatus({required this.novelId});
  
  @override
  List<Object> get props => [novelId];
}