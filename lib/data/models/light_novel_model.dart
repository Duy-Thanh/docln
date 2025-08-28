import '../../domain/entities/light_novel.dart';

class LightNovelModel extends LightNovelEntity {
  const LightNovelModel({
    required super.id,
    required super.title,
    required super.coverUrl,
    required super.url,
    super.chapters,
    super.latestChapter,
    super.rating,
    super.reviews,
    super.alternativeTitles,
    super.wordCount,
    super.views,
    super.lastUpdated,
    super.createdAt,
    super.updatedAt,
  });

  factory LightNovelModel.fromJson(Map<String, dynamic> json) {
    return LightNovelModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? 'https://ln.hako.vn/img/nocover.jpg',
      url: json['url'] ?? '',
      chapters: json['chapters'],
      latestChapter: json['latestChapter'],
      rating: json['rating']?.toDouble(),
      reviews: json['reviews'],
      alternativeTitles: json['alternativeTitles'] != null
          ? List<String>.from(json['alternativeTitles'])
          : null,
      wordCount: json['wordCount'],
      views: json['views'],
      lastUpdated: json['lastUpdated'],
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
      'title': title,
      'coverUrl': coverUrl,
      'url': url,
      'chapters': chapters,
      'latestChapter': latestChapter,
      'rating': rating,
      'reviews': reviews,
      'alternativeTitles': alternativeTitles,
      'wordCount': wordCount,
      'views': views,
      'lastUpdated': lastUpdated,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory LightNovelModel.fromEntity(LightNovelEntity entity) {
    return LightNovelModel(
      id: entity.id,
      title: entity.title,
      coverUrl: entity.coverUrl,
      url: entity.url,
      chapters: entity.chapters,
      latestChapter: entity.latestChapter,
      rating: entity.rating,
      reviews: entity.reviews,
      alternativeTitles: entity.alternativeTitles,
      wordCount: entity.wordCount,
      views: entity.views,
      lastUpdated: entity.lastUpdated,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
