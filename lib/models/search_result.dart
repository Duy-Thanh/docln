class SearchResult {
  final String id; // THÊM CÁI NÀY VÀO
  final String title;
  final String url;
  final String coverUrl;
  final String chapterTitle;
  final String chapterUrl;
  final String volumeTitle;
  final bool isOriginal;
  final String seriesTitle;
  final String seriesUrl;

  SearchResult({
    this.id = '', // Mặc định rỗng để không lỗi code cũ
    required this.title,
    required this.url,
    required this.coverUrl,
    required this.chapterTitle,
    required this.chapterUrl,
    required this.volumeTitle,
    this.isOriginal = false,
    required this.seriesTitle,
    required this.seriesUrl,
  });

  factory SearchResult.fromHtml(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id']?.toString() ?? '', // Thêm dòng này
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      coverUrl: json['coverUrl'] ?? 'https://docln.sbs/img/nocover.jpg',
      chapterTitle: json['chapterTitle'] ?? '',
      chapterUrl: json['chapterUrl'] ?? '',
      volumeTitle: json['volumeTitle'] ?? '',
      isOriginal: json['isOriginal'] ?? false,
      seriesTitle: json['seriesTitle'] ?? '',
      seriesUrl: json['seriesUrl'] ?? '',
    );
  }
}

class SearchResponse {
  final List<SearchResult> results;
  final bool hasResults;
  final int currentPage;
  final int totalPages;
  final String keyword;

  SearchResponse({
    required this.results,
    required this.hasResults,
    required this.currentPage,
    required this.totalPages,
    this.keyword = '',
  });
}
