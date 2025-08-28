import 'package:equatable/equatable.dart';

/// Bookmark entity for DCL2 architecture
class BookmarkEntity extends Equatable {
  final String id;
  final String novelId;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? latestChapter;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const BookmarkEntity({
    required this.id,
    required this.novelId,
    required this.title,
    this.coverUrl,
    this.author,
    this.latestChapter,
    required this.createdAt,
    required this.updatedAt,
  });
  
  @override
  List<Object?> get props => [
    id,
    novelId,
    title,
    coverUrl,
    author,
    latestChapter,
    createdAt,
    updatedAt,
  ];
  
  BookmarkEntity copyWith({
    String? id,
    String? novelId,
    String? title,
    String? coverUrl,
    String? author,
    String? latestChapter,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookmarkEntity(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      author: author ?? this.author,
      latestChapter: latestChapter ?? this.latestChapter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}