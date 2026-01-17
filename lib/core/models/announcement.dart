class Announcement {
  final String title;
  final String url;
  final String? color;

  Announcement({required this.title, required this.url, this.color});

  factory Announcement.fromHtml(String html) {
    final urlRegex = RegExp(r'href="([^"]*)"');
    final urlMatch = urlRegex.firstMatch(html);
    final url = urlMatch?.group(1) ?? '';

    // Better color extraction regex that handles spaces and quotes properly
    String? color;
    if (html.contains('style') && html.contains('color:')) {
      final styleRegex = RegExp(r'style="([^"]*)"');
      final styleMatch = styleRegex.firstMatch(html);
      final styleAttr = styleMatch?.group(1) ?? '';

      if (styleAttr.contains('color:')) {
        final colorRegex = RegExp(r'color:\s*(.*?)(?:;|$)');
        final colorMatch = colorRegex.firstMatch(styleAttr);
        color = colorMatch?.group(1)?.trim();
      }
    }

    final titleRegex = RegExp(r'>([^<]+)</a>');
    final titleMatch = titleRegex.firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '';

    return Announcement(title: title, url: url, color: color);
  }

  @override
  String toString() {
    return 'Announcement(title: "$title", url: "$url", color: "$color")';
  }
}
