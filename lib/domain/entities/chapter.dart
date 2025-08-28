import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String id;
  final String novelId;
  final String title;
  final String url;
  final double? chapterNumber;
  final String? content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChapterEntity({
    required this.id,
    required this.novelId,
    required this.title,
    required this.url,
    this.chapterNumber,
    this.content,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        novelId,
        title,
        url,
        chapterNumber,
        content,
        createdAt,
        updatedAt,
      ];
}
