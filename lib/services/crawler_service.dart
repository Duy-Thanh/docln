import 'package:flutter/material.dart'; // Import for BuildContext
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import '../modules/announcement.dart';
import '../screens/custom_toast.dart';

class CrawlerService {
  static const List<String> servers = [
    'https://ln.hako.vn',
    'https://ln.hako.re',
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
        }
      }

      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      CustomToast.show(context, 'Error fetching announcements: $e'); // Use custom toast
      throw Exception('Error fetching announcements.'); // Throw exception to be caught in LibraryScreen
    }
  }
}
