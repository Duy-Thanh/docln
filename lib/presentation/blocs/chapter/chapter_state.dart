import '../../../domain/entities/chapter.dart';
import '../base/base_bloc.dart';

abstract class ChapterState extends BaseState {
  const ChapterState();
}

class ChapterInitial extends ChapterState {
  const ChapterInitial();
}

class ChapterLoading extends ChapterState {
  const ChapterLoading();
}

class ChaptersLoaded extends ChapterState {
  final List<ChapterEntity> chapters;

  const ChaptersLoaded(this.chapters);

  @override
  List<Object?> get props => [chapters];
}

class ChapterLoaded extends ChapterState {
  final ChapterEntity chapter;

  const ChapterLoaded(this.chapter);

  @override
  List<Object?> get props => [chapter];
}

class ChapterContentLoaded extends ChapterState {
  final String content;

  const ChapterContentLoaded(this.content);

  @override
  List<Object?> get props => [content];
}

class ChapterError extends ChapterState {
  final String message;

  const ChapterError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChapterNavigationSuccess extends ChapterState {
  final ChapterEntity chapter;

  const ChapterNavigationSuccess(this.chapter);

  @override
  List<Object?> get props => [chapter];
}

class NoNextChapter extends ChapterState {
  const NoNextChapter();
}

class NoPreviousChapter extends ChapterState {
  const NoPreviousChapter();
}
