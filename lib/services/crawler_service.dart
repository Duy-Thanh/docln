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
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        // Find the popular novels section
        final novelsContainer = document.querySelector('.thumb-item-flow');
        if (novelsContainer == null) return [];

        final novels = novelsContainer.querySelectorAll('.thumb-item-flow').map((element) {
          // Extract novel data
          final titleElement = element.querySelector('.series-title a');
          final coverElement = element.querySelector('.content.img-in-ratio');
          final chapterElement = element.querySelector('.chapter-title');
          final ratingElement = element.querySelector('.thumb_attr.rating');
          
          // Get background image URL from style attribute
          String coverUrl = 'https://ln.hako.vn/img/nocover.jpg';
          final styleAttr = coverElement?.attributes['style'] ?? '';
          final bgUrlMatch = RegExp(r"url\('([^']+)'\)").firstMatch(styleAttr);
          if (bgUrlMatch != null) {
            coverUrl = bgUrlMatch.group(1) ?? coverUrl;
          }

          return LightNovel(
            id: titleElement?.attributes['href']?.split('-').last ?? '',
            title: titleElement?.text ?? 'Unknown Title',
            coverUrl: coverUrl,
            url: titleElement?.attributes['href'] ?? '',
            chapters: int.tryParse(chapterElement?.text.replaceAll(RegExp(r'[^0-9]'), '') ?? '0'),
            rating: double.tryParse(ratingElement?.text ?? '0'),
            reviews: int.tryParse(element.querySelector('.thumb_attr.reviews')?.text ?? '0'),
          );
        }).toList();

        return novels;
      }

      throw Exception('Failed to fetch popular novels');
    } catch (e) {
      print('Error fetching popular novels: $e');
      CustomToast.show(context, 'Error fetching popular novels: $e');
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
