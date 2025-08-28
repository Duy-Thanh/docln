import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/bookmark_entity.dart';

part 'bookmark_model.g.dart';

/// Bookmark model for DCL2 architecture
@JsonSerializable()
class BookmarkModel extends BookmarkEntity {
  const BookmarkModel({
    required super.id,
    required super.novelId,
    required super.title,
    super.coverUrl,
    super.author,
    super.latestChapter,
    required super.createdAt,
    required super.updatedAt,
  });
  
  /// Create from JSON
  factory BookmarkModel.fromJson(Map<String, dynamic> json) =>
      _$BookmarkModelFromJson(json);
  
  /// Convert to JSON
  Map<String, dynamic> toJson() => _$BookmarkModelToJson(this);
  
  /// Create from entity
  factory BookmarkModel.fromEntity(BookmarkEntity entity) {
    return BookmarkModel(
      id: entity.id,
      novelId: entity.novelId,
      title: entity.title,
      coverUrl: entity.coverUrl,
      author: entity.author,
      latestChapter: entity.latestChapter,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
  
  /// Create from legacy LightNovel for migration
  factory BookmarkModel.fromLightNovel(
    String id,
    Map<String, dynamic> lightNovelJson,
  ) {
    final now = DateTime.now();
    return BookmarkModel(
      id: id,
      novelId: lightNovelJson['id'] ?? '',
      title: lightNovelJson['title'] ?? '',
      coverUrl: lightNovelJson['coverUrl'],
      author: lightNovelJson['author'],
      latestChapter: lightNovelJson['latestChapter'],
      createdAt: now,
      updatedAt: now,
    );
  }
}