class Chapter {
  final String title;
  final String url;
  final String coverUrl;
  final String seriesTitle;
  final String seriesUrl;
  final String? volumeTitle;

  Chapter({
    required this.title,
    required this.url,
    required this.coverUrl,
    required this.seriesTitle,
    required this.seriesUrl,
    this.volumeTitle,
  });

  factory Chapter.fromHtml(String html) {
    // Parse the HTML structure similar to the provided example
    final titleRegex = RegExp(r'title="([^"]*)"');
    final urlRegex = RegExp(r'href="([^"]*)"');
    final coverRegex = RegExp(r'data-bg="([^"]*)"');
    final seriesTitleRegex = RegExp(r'series-title.*?title="([^"]*)"');
    final volumeTitleRegex = RegExp(r'volume-title">(.*?)</div>');

    final titleMatch = titleRegex.firstMatch(html);
    final urlMatch = urlRegex.firstMatch(html);
    final coverMatch = coverRegex.firstMatch(html);
    final seriesTitleMatch = seriesTitleRegex.firstMatch(html);
    final volumeTitleMatch = volumeTitleRegex.firstMatch(html);

    return Chapter(
      title: titleMatch?.group(1) ?? '',
      url: urlMatch?.group(1) ?? '',
      coverUrl: coverMatch?.group(1) ?? 'https://docln.sbs/img/nocover.jpg',
      seriesTitle: seriesTitleMatch?.group(1) ?? '',
      seriesUrl: '', // Extract from series link
      volumeTitle: volumeTitleMatch?.group(1),
    );
  }
}
