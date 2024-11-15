class Announcement {
  final String title;
  final String url;
  final String? color;

  Announcement({required this.title, required this.url, this.color});

  factory Announcement.fromHtml(String html) {
    final urlRegex = RegExp(r'href="([^"]*)"');
    final urlMatch = urlRegex.firstMatch(html);
    final url = urlMatch?.group(1) ?? '';

    // Color
    final colorRegex = RegExp(r'color:\s*([^"]*)"');
    final colorMatch = colorRegex.firstMatch(html);
    final color = colorMatch?.group(1)?.trim();

    final titleRegex = RegExp(r'>([^<]+)</a>');
    final titleMatch = titleRegex.firstMatch(html);
    final title = titleMatch?.group(1) ?? '';

    return Announcement(title: title, url: url, color: color);
  }
}