class LightNovel {
  final String id;
  final String title;
  final String coverUrl;
  final String url;
  final int? chapters;
  final String? latestChapter;
  final String? volumeTitle;
  final double? rating;
  final int? reviews;
  final List<String>? alternativeTitles;
  final int? wordCount;
  final int? views;
  final String? lastUpdated;

  LightNovel({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
    this.chapters,
    this.latestChapter,
    this.volumeTitle,
    this.rating,
    this.reviews,
    this.alternativeTitles,
    this.wordCount,
    this.views,
    this.lastUpdated,
  });

  factory LightNovel.fromJson(Map<String, dynamic> json) {
    return LightNovel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? 'https://ln.hako.vn/img/nocover.jpg',
      url: json['url'] ?? '',
      chapters: json['chapters'],
      latestChapter: json['latestChapter'],
      volumeTitle: json['volumeTitle'],
      rating: json['rating']?.toDouble(),
      reviews: json['reviews'],
      alternativeTitles: json['alternativeTitles']?.cast<String>(),
      wordCount: json['wordCount'],
      views: json['views'],
      lastUpdated: json['lastUpdated'],
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
      'volumeTitle': volumeTitle,
      'rating': rating,
      'reviews': reviews,
      'alternativeTitles': alternativeTitles,
      'wordCount': wordCount,
      'views': views,
      'lastUpdated': lastUpdated,
    };
  }
}
