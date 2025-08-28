import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_chapters.dart';
import '../base/base_bloc.dart';
import 'chapter_event.dart';
import 'chapter_state.dart';

@Injectable()
class ChapterBloc extends BaseBloc<ChapterEvent, ChapterState> {
  final GetChaptersUseCase _getChaptersUseCase;
  final GetChapterUseCase _getChapterUseCase;
  final GetChapterContentUseCase _getChapterContentUseCase;
  final GetNextChapterUseCase _getNextChapterUseCase;
  final GetPreviousChapterUseCase _getPreviousChapterUseCase;

  ChapterBloc(
    this._getChaptersUseCase,
    this._getChapterUseCase,
    this._getChapterContentUseCase,
    this._getNextChapterUseCase,
    this._getPreviousChapterUseCase,
  ) : super(const ChapterInitial()) {
    on<LoadChapters>(_onLoadChapters);
    on<LoadChapter>(_onLoadChapter);
    on<LoadChapterContent>(_onLoadChapterContent);
    on<MarkChapterAsRead>(_onMarkChapterAsRead);
    on<LoadNextChapter>(_onLoadNextChapter);
    on<LoadPreviousChapter>(_onLoadPreviousChapter);
  }

  Future<void> _onLoadChapters(
    LoadChapters event,
    Emitter<ChapterState> emit,
  ) async {
    emit(const ChapterLoading());

    final result = await _getChaptersUseCase(event.novelId);

    result.fold(
      (failure) => emit(ChapterError(failure.message)),
      (chapters) => emit(ChaptersLoaded(chapters)),
    );
  }

  Future<void> _onLoadChapter(
    LoadChapter event,
    Emitter<ChapterState> emit,
  ) async {
    emit(const ChapterLoading());

    final result = await _getChapterUseCase(event.chapterId);

    result.fold(
      (failure) => emit(ChapterError(failure.message)),
      (chapter) => emit(ChapterLoaded(chapter)),
    );
  }

  Future<void> _onLoadChapterContent(
    LoadChapterContent event,
    Emitter<ChapterState> emit,
  ) async {
    emit(const ChapterLoading());

    final result = await _getChapterContentUseCase(event.chapterId);

    result.fold(
      (failure) => emit(ChapterError(failure.message)),
      (content) => emit(ChapterContentLoaded(content)),
    );
  }

  Future<void> _onMarkChapterAsRead(
    MarkChapterAsRead event,
    Emitter<ChapterState> emit,
  ) async {
    // Implementation for marking chapter as read
    // This would typically call a use case
    // For now, we'll just emit a success state or handle it differently
  }

  Future<void> _onLoadNextChapter(
    LoadNextChapter event,
    Emitter<ChapterState> emit,
  ) async {
    emit(const ChapterLoading());

    final result = await _getNextChapterUseCase(
      GetAdjacentChapterParams(
        currentChapterId: event.currentChapterId,
        novelId: event.novelId,
      ),
    );

    result.fold(
      (failure) => emit(ChapterError(failure.message)),
      (chapter) => chapter != null
          ? emit(ChapterNavigationSuccess(chapter))
          : emit(const NoNextChapter()),
    );
  }

  Future<void> _onLoadPreviousChapter(
    LoadPreviousChapter event,
    Emitter<ChapterState> emit,
  ) async {
    emit(const ChapterLoading());

    final result = await _getPreviousChapterUseCase(
      GetAdjacentChapterParams(
        currentChapterId: event.currentChapterId,
        novelId: event.novelId,
      ),
    );

    result.fold(
      (failure) => emit(ChapterError(failure.message)),
      (chapter) => chapter != null
          ? emit(ChapterNavigationSuccess(chapter))
          : emit(const NoPreviousChapter()),
    );
  }
}
