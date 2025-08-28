import '../../domain/entities/chapter.dart';

class ChapterModel extends ChapterEntity {
  const ChapterModel({
    required super.id,
    required super.novelId,
    required super.title,
    required super.url,
    super.chapterNumber,
    super.content,
    super.createdAt,
    super.updatedAt,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] ?? '',
      novelId: json['novelId'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      chapterNumber: json['chapterNumber']?.toDouble(),
      content: json['content'],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'novelId': novelId,
      'title': title,
      'url': url,
      'chapterNumber': chapterNumber,
      'content': content,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ChapterModel.fromEntity(ChapterEntity entity) {
    return ChapterModel(
      id: entity.id,
      novelId: entity.novelId,
      title: entity.title,
      url: entity.url,
      chapterNumber: entity.chapterNumber,
      content: entity.content,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
