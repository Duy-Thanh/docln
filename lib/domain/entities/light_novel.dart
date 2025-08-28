import 'package:equatable/equatable.dart';

class LightNovelEntity extends Equatable {
  final String id;
  final String title;
  final String coverUrl;
  final String url;
  final int? chapters;
  final String? latestChapter;
  final double? rating;
  final int? reviews;
  final List<String>? alternativeTitles;
  final int? wordCount;
  final int? views;
  final String? lastUpdated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LightNovelEntity({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
    this.chapters,
    this.latestChapter,
    this.rating,
    this.reviews,
    this.alternativeTitles,
    this.wordCount,
    this.views,
    this.lastUpdated,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        coverUrl,
        url,
        chapters,
        latestChapter,
        rating,
        reviews,
        alternativeTitles,
        wordCount,
        views,
        lastUpdated,
        createdAt,
        updatedAt,
      ];
}
