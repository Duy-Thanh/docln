import 'package:flutter/material.dart'; // Import for BuildContext
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
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
        final response = await http.get(
          Uri.parse(server),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
          },
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Failed to connect to the server: $server: Connection timeout');
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
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36'
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
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final announcementsDiv = document.getElementById('announcements');

        if (announcementsDiv != null) {
          final announcements = announcementsDiv
            .getElementsByClassName('annoucement-item')
            .map((element) {
              final anchorTag = element.getElementsByTagName('a').first;
              return Announcement(
                title: anchorTag.text,
                url: workingServer + anchorTag.attributes['href']!,
                color: anchorTag.attributes['style']?.replaceAll(RegExp(r'color:\s*'), ''),
              );
            })
            .toList();

          return announcements;
        } else {
          throw Exception('Server error (${response.statusCode}). Please try again later.');
        }
      }

      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      CustomToast.show(context, 'Error fetching announcements: $e'); // Use custom toast
      throw Exception('Error fetching announcements.'); // Throw exception to be caught in LibraryScreen
    }
  }

  Future<List<LightNovel>> getPopularNovels(BuildContext context) async {
    try {
      final server = await _getWorkingServer();
      if (server == null) {
        CustomToast.show(context, 'No server available');
        return [];
      }

      final response = await http.get(
        Uri.parse(server)
      );
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final novelElements = document.querySelectorAll('.daily-recent_views .popular-thumb-item');
        
        final novels = <LightNovel>[];
        
        for (var element in novelElements) {
          try {
            final titleElement = element.querySelector('.thumb_attr.series-title a');
            final coverElement = element.querySelector('.content.img-in-ratio');
            final linkElement = element.querySelector('.thumb-wrapper a');

            if (titleElement != null && coverElement != null && linkElement != null) {
              final title = titleElement.text.trim();
              final relativeUrl = linkElement.attributes['href'] ?? '';
              // Convert relative URL to absolute URL
              final url = relativeUrl.startsWith('http') 
                  ? relativeUrl 
                  : '$server$relativeUrl';
              final id = relativeUrl.split('/').last;
              
              // Extract cover URL from style attribute
              final styleAttr = coverElement.attributes['style'] ?? '';
              final coverUrlMatch = RegExp(r"url\('([^']+)'\)").firstMatch(styleAttr);
              final coverUrl = coverUrlMatch?.group(1) ?? 'https://ln.hako.vn/img/nocover.jpg';

              novels.add(LightNovel(
                id: id,
                title: title,
                coverUrl: coverUrl,
                url: url,  // Now using the absolute URL
              ));
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

      final response = await http.get(
        Uri.parse(server)
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        // Updated selector to match the creative novels section
        final novelElements = document.querySelectorAll('.thumb-section-flow.original.one-row .thumb-item-flow:not(.see-more)');
        
        final novels = <LightNovel>[];
        
        for (var element in novelElements) {
          try {
            final titleElement = element.querySelector('.thumb_attr.series-title a');
            final coverElement = element.querySelector('.content.img-in-ratio');
            final chapterElement = element.querySelector('.thumb_attr.chapter-title a');
            final volumeElement = element.querySelector('.thumb_attr.volume-title');

            if (titleElement != null && coverElement != null) {
              final title = titleElement.text.trim();
              final relativeUrl = titleElement.attributes['href'] ?? '';
              final url = relativeUrl.startsWith('http') 
                  ? relativeUrl 
                  : '$server$relativeUrl';
              final id = relativeUrl.split('/').last;
              
              // Get cover URL from data-bg attribute
              String coverUrl = coverElement.attributes['data-bg'] ?? '';
              if (coverUrl.isEmpty) {
                final styleAttr = coverElement.attributes['style'] ?? '';
                final coverUrlMatch = RegExp(r'url\("([^"]+)"\)').firstMatch(styleAttr);
                coverUrl = coverUrlMatch?.group(1) ?? 'https://ln.hako.vn/img/nocover.jpg';
              }

              // Extract chapter number if available
              int? chapters;
              String? latestChapter;
              if (chapterElement != null) {
                final chapterText = chapterElement.text;
                final chapterMatch = RegExp(r'Chương (\d+)').firstMatch(chapterText);
                if (chapterMatch != null) {
                  chapters = int.tryParse(chapterMatch.group(1) ?? '');
                }
                latestChapter = chapterText;
              }

              // Extract volume title
              final volumeTitle = volumeElement?.text.trim();

              novels.add(LightNovel(
                id: id,
                title: title,
                coverUrl: coverUrl,
                url: url,
                chapters: chapters,
                latestChapter: latestChapter,
                volumeTitle: volumeTitle,
              ));
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
  Future<Map<String, dynamic>> getNovelDetails(String url, BuildContext context) async {
    try {
      final workingServer = await _getWorkingServer();
      if (workingServer == null) {
        throw Exception('No working server available');
      }

      final response = await http.get(
        Uri.parse('$workingServer$url'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        return {
          'title': document.querySelector('.series-name')?.text ?? '',
          'author': document.querySelector('.author')?.text ?? '',
          'status': document.querySelector('.status')?.text ?? '',
          'genres': document.querySelectorAll('.genre').map((e) => e.text).toList(),
          'summary': document.querySelector('.summary')?.text ?? '',
          'chapters': document.querySelectorAll('.chapter-item').map((e) {
            return {
              'title': e.querySelector('.chapter-title')?.text ?? '',
              'url': e.querySelector('a')?.attributes['href'] ?? '',
              'date': e.querySelector('.chapter-time')?.text ?? '',
            };
          }).toList(),
        };
      }

      throw Exception('Failed to fetch novel details');
    } catch (e) {
      print('Error fetching novel details: $e');
      CustomToast.show(context, 'Error fetching novel details: $e');
      return {};
    }
  }
}
