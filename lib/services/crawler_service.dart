import 'package:flutter/material.dart'; // Import for BuildContext
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import '../modules/announcement.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../modules/chapter.dart';

class CrawlerService {
  static const List<String> servers = [
    'https://ln.hako.vn',
    'https://docln.net',
  ];

  Future<String?> _getWorkingServer() async {
    for (String server in servers) {
      try {
        final response = await http
            .get(
              Uri.parse(server),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
              },
            )
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw Exception(
                  'Failed to connect to the server: $server: Connection timeout',
                );
              },
            );

        if (response.statusCode == 200) {
          return server;
        }
      } catch (e) {
        print('Failed to connect to the server: $server. Error: $e');
        continue;
      }
    }

    return null;
  }

  Future<List<Chapter>> getLatestChapters(BuildContext context) async {
    try {
      final workingServer = await _getWorkingServer();
      if (workingServer == null) {
        throw Exception('No working server available');
      }

      final response = await http.get(
        Uri.parse('$workingServer'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final chapterElements = document.querySelectorAll('.thumb-item-flow');

        return chapterElements.map((element) {
          final html = element.outerHtml;
          return Chapter.fromHtml(html);
        }).toList();
      }

      throw Exception('Failed to fetch latest chapters');
    } catch (e) {
      print('Error fetching latest chapters: $e');
      CustomToast.show(context, 'Error fetching latest chapters');
      return [];
    }
  }

  Future<List<Announcement>> getAnnouncements(BuildContext context) async {
    try {
      final workingServer = await _getWorkingServer();

      if (workingServer == null) {
        throw Exception('None of the servers are working.'); // Custom message
      }

      final response = await http.get(
        Uri.parse(workingServer),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final announcementsDiv = document.getElementById('announcements');

        if (announcementsDiv != null) {
          final announcements = <Announcement>[];

          // Get announcement items either through class or based on structure
          final announcementItems = announcementsDiv.getElementsByClassName(
            'annoucement-item',
          );

          for (var element in announcementItems) {
            try {
              final anchorTag = element.getElementsByTagName('a').first;
              final title = anchorTag.text.trim();
              final relativeUrl = anchorTag.attributes['href'] ?? '';
              final url =
                  relativeUrl.startsWith('http')
                      ? relativeUrl
                      : '$workingServer$relativeUrl';

              // Extract color with proper regex
              String? color;
              final styleAttr = anchorTag.attributes['style'] ?? '';
              if (styleAttr.contains('color:')) {
                // The regex now matches any characters between "color:" and the end of the attribute or a semicolon
                final colorMatch = RegExp(
                  r'color:\s*(.*?)(?:;|"|\s*$)',
                ).firstMatch(styleAttr);
                if (colorMatch != null && colorMatch.group(1) != null) {
                  color = colorMatch.group(1)!.trim();
                }
              }

              announcements.add(
                Announcement(title: title, url: url, color: color),
              );
            } catch (e) {
              print('Error parsing announcement item: $e');
              continue;
            }
          }

          print('Found ${announcements.length} announcements');
          return announcements;
        } else {
          print('No announcements div found');
          return [];
        }
      }

      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      CustomToast.show(
        context,
        'Error fetching announcements: $e',
      ); // Use custom toast
      return []; // Return empty list instead of throwing to prevent crashes
    }
  }

  Future<List<LightNovel>> getPopularNovels(BuildContext context) async {
    try {
      final server = await _getWorkingServer();
      if (server == null) {
        CustomToast.show(context, 'No server available');
        return [];
      }

      final response = await http.get(Uri.parse(server));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final novelElements = document.querySelectorAll(
          '.daily-recent_views .popular-thumb-item',
        );

        final novels = <LightNovel>[];

        for (var element in novelElements) {
          try {
            final titleElement = element.querySelector(
              '.thumb_attr.series-title a',
            );
            final coverElement = element.querySelector('.content.img-in-ratio');
            final linkElement = element.querySelector('.thumb-wrapper a');

            if (titleElement != null &&
                coverElement != null &&
                linkElement != null) {
              final title = titleElement.text.trim();
              final relativeUrl = linkElement.attributes['href'] ?? '';
              // Convert relative URL to absolute URL
              final url =
                  relativeUrl.startsWith('http')
                      ? relativeUrl
                      : '$server$relativeUrl';
              final id = relativeUrl.split('/').last;

              // Extract cover URL from style attribute
              final styleAttr = coverElement.attributes['style'] ?? '';
              final coverUrlMatch = RegExp(
                r"url\('([^']+)'\)",
              ).firstMatch(styleAttr);
              final coverUrl =
                  coverUrlMatch?.group(1) ??
                  'https://ln.hako.vn/img/nocover.jpg';

              novels.add(
                LightNovel(
                  id: id,
                  title: title,
                  coverUrl: coverUrl,
                  url: url, // Now using the absolute URL
                ),
              );
            }
          } catch (e) {
            print('Error parsing novel element: $e');
            continue;
          }
        }

        return novels;
      }

      CustomToast.show(context, 'Failed to fetch popular novels');
      return [];
    } catch (e) {
      print('Error fetching popular novels: $e');
      CustomToast.show(context, 'Error fetching popular novels: $e');
      return [];
    }
  }

  Future<List<LightNovel>> getCreativeNovels(BuildContext context) async {
    try {
      final server = await _getWorkingServer();
      if (server == null) {
        CustomToast.show(context, 'No server available');
        return [];
      }

      final response = await http.get(Uri.parse(server));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        // Updated selector to match the creative novels section
        final novelElements = document.querySelectorAll(
          '.thumb-section-flow.original.one-row .thumb-item-flow:not(.see-more)',
        );

        final novels = <LightNovel>[];

        for (var element in novelElements) {
          try {
            final titleElement = element.querySelector(
              '.thumb_attr.series-title a',
            );
            final coverElement = element.querySelector('.content.img-in-ratio');
            final chapterElement = element.querySelector(
              '.thumb_attr.chapter-title a',
            );
            final volumeElement = element.querySelector(
              '.thumb_attr.volume-title',
            );

            if (titleElement != null && coverElement != null) {
              final title = titleElement.text.trim();
              final relativeUrl = titleElement.attributes['href'] ?? '';
              final url =
                  relativeUrl.startsWith('http')
                      ? relativeUrl
                      : '$server$relativeUrl';
              final id = relativeUrl.split('/').last;

              // Get cover URL from data-bg attribute
              String coverUrl = coverElement.attributes['data-bg'] ?? '';
              if (coverUrl.isEmpty) {
                final styleAttr = coverElement.attributes['style'] ?? '';
                final coverUrlMatch = RegExp(
                  r'url\("([^"]+)"\)',
                ).firstMatch(styleAttr);
                coverUrl =
                    coverUrlMatch?.group(1) ??
                    'https://ln.hako.vn/img/nocover.jpg';
              }

              // Extract chapter number if available
              int? chapters;
              String? latestChapter;
              if (chapterElement != null) {
                final chapterText = chapterElement.text;
                final chapterMatch = RegExp(
                  r'Chương (\d+)',
                ).firstMatch(chapterText);
                if (chapterMatch != null) {
                  chapters = int.tryParse(chapterMatch.group(1) ?? '');
                }
                latestChapter = chapterText;
              }

              // Extract volume title
              final volumeTitle = volumeElement?.text.trim();

              novels.add(
                LightNovel(
                  id: id,
                  title: title,
                  coverUrl: coverUrl,
                  url: url,
                  chapters: chapters,
                  latestChapter: latestChapter,
                  volumeTitle: volumeTitle,
                ),
              );
            }
          } catch (e) {
            print('Error parsing creative novel element: $e');
            continue;
          }
        }

        return novels;
      }

      CustomToast.show(context, 'Failed to fetch creative novels');
      return [];
    } catch (e) {
      print('Error fetching creative novels: $e');
      CustomToast.show(context, 'Error fetching creative novels: $e');
      return [];
    }
  }

  // Add method to extract novel details
  Future<Map<String, dynamic>> getNovelDetails(
    String url,
    BuildContext context,
  ) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Extract basic info
        final titleElement = document.querySelector('.series-name a');
        final coverElement = document.querySelector(
          '.series-cover .content.img-in-ratio',
        );

        // Find author and status using a more compatible approach instead of :contains()
        final authorElement = _findElementWithLabel(document, 'Tác giả');
        final statusElement = _findElementWithLabel(document, 'Tình trạng');
        final summaryElement = document.querySelector('.summary-content');

        // Extract novel type (Original, Truyện dịch, etc.)
        String novelType = 'Truyện dịch'; // Default value

        // Try to find the type label in multiple places
        final novelTypeElement = document.querySelector('.series-type');
        if (novelTypeElement != null) {
          novelType = novelTypeElement.text.trim();
        } else {
          // Alternative way: check if it's in the series name section
          final seriesTypeTag = document.querySelector('.series-name .badge');
          if (seriesTypeTag != null) {
            novelType = seriesTypeTag.text.trim();
          } else {
            // Check if it has an "Original" tag anywhere
            final originalTag = document.querySelector('.type-original');
            if (originalTag != null) {
              novelType = 'Original';
            }
          }
        }

        // If nothing found, see if summary contains the type
        if (novelType.isEmpty && summaryElement != null) {
          final summaryText = summaryElement.text.trim();
          if (summaryText.contains('Truyện dịch')) {
            novelType = 'Truyện dịch';
          } else if (summaryText.contains('Original')) {
            novelType = 'Original';
          }
        }

        // Extract genres
        final genreElements = document.querySelectorAll('.series-gerne-item');
        final genres =
            genreElements
                .where((e) => !e.text.contains('...'))
                .map((e) => e.text.trim())
                .toList();

        // Extract chapters
        final chapterElements = document.querySelectorAll('.chapter-name');
        final chapters = <Map<String, dynamic>>[];

        for (var element in chapterElements) {
          final titleElement = element.querySelector('a');
          final dateElement = element.nextElementSibling?.querySelector(
            '.chapter-time',
          );

          if (titleElement != null) {
            final title = titleElement.text.trim();
            final url = titleElement.attributes['href'] ?? '';
            final date = dateElement?.text.trim() ?? '';

            chapters.add({'title': title, 'url': url, 'date': date});
          }
        }

        // Extract word count, views, and rating
        int? wordCount;
        int? views;
        double? rating;
        int? reviews;

        // Find fact items
        final wordCountElement = _findFactElement(document, 'Số từ');
        final viewsElement = _findFactElement(document, 'Lượt xem');
        final ratingElement = _findFactElement(document, 'Đánh giá');
        final lastUpdatedElement = _findFactElement(document, 'Lần cuối');

        // Parse word count
        if (wordCountElement != null) {
          final wordCountStr = wordCountElement.text.replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          wordCount = int.tryParse(wordCountStr);
        }

        // Parse views
        if (viewsElement != null) {
          final viewsStr = viewsElement.text.replaceAll(RegExp(r'[^0-9]'), '');
          views = int.tryParse(viewsStr);
        }

        // Parse rating
        if (ratingElement != null) {
          final ratingText = ratingElement.text.trim();
          // Check for pattern like "4.5 / 5 - 123 đánh giá"
          final ratingMatch = RegExp(
            r'(\d+\.?\d*)\s*\/\s*\d+(?:\s*-\s*(\d+)\s*đánh giá)?',
          ).firstMatch(ratingText);

          if (ratingMatch != null && ratingMatch.group(1) != null) {
            rating = double.tryParse(ratingMatch.group(1)!);
            // Try to parse reviews count
            if (ratingMatch.group(2) != null) {
              reviews = int.tryParse(ratingMatch.group(2)!);
            }
          } else {
            // Try alternative pattern if the first one doesn't match
            final parts = ratingText.split('-');
            if (parts.isNotEmpty) {
              final ratingPart = parts[0].trim();
              final ratingVal = ratingPart.split('/')[0].trim();
              rating = double.tryParse(ratingVal);
            }

            // Try to parse the reviews part if available
            if (parts.length >= 2) {
              // Extract only digits from the second part
              final reviewsStr = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
              reviews = int.tryParse(reviewsStr);
            }
          }
        }

        // Extract last updated
        String? lastUpdated;
        if (lastUpdatedElement != null) {
          // Try to find the timeago element first
          final timeElement = lastUpdatedElement.querySelector('time.timeago');
          if (timeElement != null) {
            // Get the title attribute which contains the full date
            lastUpdated =
                timeElement.attributes['title'] ?? timeElement.text.trim();
          } else {
            // Fallback to the text content
            lastUpdated = lastUpdatedElement.text.trim();
          }
        }

        // Extract alternative titles
        final altTitlesElement = _findFactElement(document, 'Tên khác');
        final alternativeTitles = <String>[];

        if (altTitlesElement != null) {
          final altTitlesBlocks = altTitlesElement.querySelectorAll('.block');
          for (final block in altTitlesBlocks) {
            final title = block.text.trim();
            if (title.isNotEmpty) {
              alternativeTitles.add(title);
            }
          }
        }

        return {
          'title': titleElement?.text.trim() ?? '',
          'cover': _extractCoverUrl(coverElement),
          'author': authorElement?.text.trim() ?? '',
          'status': statusElement?.text.trim() ?? '',
          'summary': summaryElement?.text.trim() ?? '',
          'genres': genres,
          'chapters': chapters,
          'wordCount': wordCount,
          'views': views,
          'rating': rating,
          'reviews': reviews,
          'lastUpdated': lastUpdated,
          'alternativeTitles': alternativeTitles,
          'novelType': novelType,
        };
      }

      throw Exception('Failed to load novel details');
    } catch (e) {
      print('Error getting novel details: $e');
      CustomToast.show(context, 'Error loading novel details: $e');
      return {
        'summary': 'Unable to load novel details. Please try again later.',
      };
    }
  }

  // Helper method to find element with specific label
  dom.Element? _findElementWithLabel(dom.Document document, String label) {
    final infoItems = document.querySelectorAll('.info-item');
    for (final item in infoItems) {
      final nameElement = item.querySelector('.info-name');
      if (nameElement != null && nameElement.text.contains(label)) {
        return item.querySelector('.info-value a') ??
            item.querySelector('.info-value');
      }
    }
    return null;
  }

  // Helper method to find fact element by label
  dom.Element? _findFactElement(dom.Document document, String label) {
    final factItems = document.querySelectorAll('.fact-item');
    for (final item in factItems) {
      final nameElement = item.querySelector('.fact-name');
      if (nameElement != null && nameElement.text.contains(label)) {
        return item.querySelector('.fact-value');
      }
    }

    // If not found in fact items, try the statistic items as fallback
    final statItems = document.querySelectorAll('.statistic-item');
    for (final item in statItems) {
      final nameElement = item.querySelector('.statistic-name');
      if (nameElement != null && nameElement.text.contains(label)) {
        return item.querySelector('.statistic-value');
      }
    }

    return null;
  }

  // Extracts the cover URL from the cover element
  String _extractCoverUrl(dom.Element? coverElement) {
    if (coverElement == null) {
      return 'https://ln.hako.vn/img/nocover.jpg';
    }

    // Try to get from data-bg attribute
    String? dataBg = coverElement.attributes['data-bg'];
    if (dataBg != null && dataBg.isNotEmpty) {
      return dataBg;
    }

    // Try to get from background-image style
    String? style = coverElement.attributes['style'];
    if (style != null && style.contains('url(')) {
      // Extract URL from style using string operations instead of RegExp
      int startIndex = style.indexOf('url(') + 4;
      int endIndex = style.indexOf(')', startIndex);
      if (startIndex < endIndex) {
        String url = style.substring(startIndex, endIndex);
        // Remove quotes if they exist
        if (url.startsWith('"') && url.endsWith('"')) {
          url = url.substring(1, url.length - 1);
        } else if (url.startsWith("'") && url.endsWith("'")) {
          url = url.substring(1, url.length - 1);
        }
        return url;
      }
    }

    // If all else fails, return default image
    return 'https://ln.hako.vn/img/nocover.jpg';
  }
}
