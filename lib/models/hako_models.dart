class NovelBasic {
  final String id;
  final String title;
  final String cover;
  final String url;
  final String? latestChapter; // Dành cho list mới nhất
  final String? summary; // Dành cho list vừa đăng

  NovelBasic({
    required this.id,
    required this.title,
    required this.cover,
    required this.url,
    this.latestChapter,
    this.summary,
  });

  factory NovelBasic.fromJson(Map<String, dynamic> json) {
    return NovelBasic(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Không tên',
      cover: json['cover'] ?? '',
      url: json['url'] ?? '',
      latestChapter: json['latestChapter'],
      summary: json['summary'],
    );
  }
}

class NovelDetail {
  final String id;
  final String title;
  final String cover;
  final String author;
  final String illustrator;
  final List<String> genres;
  final String summary;
  final List<Volume> volumes;

  NovelDetail({
    required this.id,
    required this.title,
    required this.cover,
    required this.author,
    required this.illustrator,
    required this.genres,
    required this.summary,
    required this.volumes,
  });

  factory NovelDetail.fromJson(Map<String, dynamic> json) {
    return NovelDetail(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      author: json['author'] ?? '',
      illustrator: json['illustrator'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      summary: json['summary'] ?? '',
      volumes:
          (json['volumes'] as List?)?.map((e) => Volume.fromJson(e)).toList() ??
          [],
    );
  }
}

class Volume {
  final String title;
  final List<Chapter> chapters;

  Volume({required this.title, required this.chapters});

  factory Volume.fromJson(Map<String, dynamic> json) {
    return Volume(
      title: json['title'] ?? '',
      chapters:
          (json['chapters'] as List?)
              ?.map((e) => Chapter.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class Chapter {
  final String id;
  final String title;
  final String url;
  final String time;

  Chapter({
    required this.id,
    required this.title,
    required this.url,
    required this.time,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      time: json['time'] ?? '',
    );
  }
}

class ChapterContent {
  final String type; // 'text' hoặc 'image'
  final String content;

  ChapterContent({required this.type, required this.content});

  factory ChapterContent.fromJson(Map<String, dynamic> json) {
    return ChapterContent(
      type: json['type'] ?? 'text',
      content: json['content'] ?? '',
    );
  }
}
