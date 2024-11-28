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
    };
  }
}