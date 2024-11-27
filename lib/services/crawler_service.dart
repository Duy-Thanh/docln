import 'package:flutter/material.dart'; // Import for BuildContext
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import '../modules/announcement.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';

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
      final workingServer = await _getWorkingServer();
      if (workingServer == null) {
        throw Exception('No working server available');
      }

      final response = await http.get(
        Uri.parse(workingServer),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        List<LightNovel> novels = [];

        // Parse all thumb-item-flow elements (both original and translated novels)
        final novelElements = document.querySelectorAll('.thumb-item-flow:not(.see-more)');
        
        for (var element in novelElements) {
          try {
            final titleElement = element.querySelector('.thumb_attr.series-title a');
            final coverElement = element.querySelector('.content.img-in-ratio');
            final chapterElement = element.querySelector('.thumb_attr.chapter-title');
            
            if (titleElement != null) {
              final title = titleElement.text;
              final url = titleElement.attributes['href'] ?? '';
              final id = url.split('/').last;
              
              // Get cover URL from data-bg attribute or background-image style
              String coverUrl = coverElement?.attributes['data-bg'] ?? '';
              if (coverUrl.isEmpty) {
                final bgStyle = coverElement?.attributes['style'] ?? '';
                final bgMatch = RegExp(r'url\("([^"]+)"\)').firstMatch(bgStyle);
                coverUrl = bgMatch?.group(1) ?? 'https://ln.hako.vn/img/nocover.jpg';
              }

              // Get chapter count
              final chapterText = chapterElement?.text ?? '';
              final chapterMatch = RegExp(r'Chương (\d+)').firstMatch(chapterText);
              final chapters = chapterMatch != null ? 
                  int.tryParse(chapterMatch.group(1) ?? '0') : 0;

              novels.add(LightNovel(
                id: id,
                title: title,
                coverUrl: coverUrl,
                url: '$workingServer$url',
                chapters: chapters,
              ));
            }
          } catch (e) {
            print('Error parsing novel element: $e');
            continue;
          }
        }

        return novels;
      }

      throw Exception('Failed to load novels');
    } catch (e) {
      print('Error fetching novels: $e');
      CustomToast.show(context, 'Error fetching novels: $e');
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
