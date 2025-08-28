import 'package:equatable/equatable.dart';
import '../../domain/entities/bookmark_entity.dart';

/// Base state for bookmark BLoC
abstract class BookmarkState extends Equatable {
  const BookmarkState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state
class BookmarkInitial extends BookmarkState {}

/// Loading state
class BookmarkLoading extends BookmarkState {}

/// Success state with bookmarks
class BookmarkLoaded extends BookmarkState {
  final List<BookmarkEntity> bookmarks;
  
  const BookmarkLoaded({required this.bookmarks});
  
  @override
  List<Object> get props => [bookmarks];
}

/// Error state
class BookmarkError extends BookmarkState {
  final String message;
  
  const BookmarkError({required this.message});
  
  @override
  List<Object> get props => [message];
}

/// Success state for add/remove operations
class BookmarkOperationSuccess extends BookmarkState {
  final String message;
  final bool isAdded; // true for added, false for removed
  
  const BookmarkOperationSuccess({
    required this.message,
    required this.isAdded,
  });
  
  @override
  List<Object> get props => [message, isAdded];
}