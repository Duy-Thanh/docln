import '../base/base_bloc.dart';

abstract class ChapterEvent extends BaseEvent {
  const ChapterEvent();
}

class LoadChapters extends ChapterEvent {
  final String novelId;

  const LoadChapters(this.novelId);

  @override
  List<Object?> get props => [novelId];
}

class LoadChapter extends ChapterEvent {
  final String chapterId;

  const LoadChapter(this.chapterId);

  @override
  List<Object?> get props => [chapterId];
}

class LoadChapterContent extends ChapterEvent {
  final String chapterId;

  const LoadChapterContent(this.chapterId);

  @override
  List<Object?> get props => [chapterId];
}

class MarkChapterAsRead extends ChapterEvent {
  final String chapterId;

  const MarkChapterAsRead(this.chapterId);

  @override
  List<Object?> get props => [chapterId];
}

class LoadNextChapter extends ChapterEvent {
  final String currentChapterId;
  final String novelId;

  const LoadNextChapter({
    required this.currentChapterId,
    required this.novelId,
  });

  @override
  List<Object?> get props => [currentChapterId, novelId];
}

class LoadPreviousChapter extends ChapterEvent {
  final String currentChapterId;
  final String novelId;

  const LoadPreviousChapter({
    required this.currentChapterId,
    required this.novelId,
  });

  @override
  List<Object?> get props => [currentChapterId, novelId];
}
