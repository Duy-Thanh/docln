class LightNovel {
  final String id;
  final String title;
  final String coverUrl;
  final String url;

  LightNovel({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
  });

  factory LightNovel.fromJson(Map<String, dynamic> json) {
    return LightNovel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? 'https://ln.hako.vn/img/nocover.jpg',
      url: json['url'] ?? '',
    );
  }
}
