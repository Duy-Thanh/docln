import 'package:flutter/material.dart'; // Import for BuildContext
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'dart:io';
import '../modules/announcement.dart';
import '../screens/custom_toast.dart';
import '../modules/light_novel.dart';
import '../modules/chapter.dart';
import '../services/http_client.dart';
import '../services/dns_service.dart';
import '../services/settings_services.dart';
import '../services/server_management_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

class CrawlerService {
  // Server management service
  final ServerManagementService _serverManagement = ServerManagementService();
  
  // Primary server domains
  static const List<String> servers = [
    'https://docln.sbs',
    'https://ln.hako.vn',
    'https://docln.net',
  ];

  // Alternative domains for each server
  static const Map<String, List<String>> alternativeServers = {
    'https://ln.hako.vn': ['https://ln.hako.re', 'https://ln.hako.vip'],
    'https://docln.net': ['https://docln.org', 'https://docln.co'],
    'https://docln.sbs': ['https://docln.cc', 'https://docln.me'],
  };

  final AppHttpClient _httpClient = AppHttpClient();
  final DnsService _dnsService = DnsService();
  final SettingsService _settingsService = SettingsService();

  bool _isDnsEnabled = false;
  String _dnsProvider = 'Default';
  String _customDns = '';

  // Map of problematic image domains and their alternatives
  static const Map<String, List<String>> imageDomainFallbacks = {
    'i.docln.net': [
      'i3.docln.net',
      'i2.docln.net',
      'i.hako.vn',
      'i.ln.hako.vn',
      'i.hako.vip',
      'i2.hako.vip',
    ],
    'i2.docln.net': [
      'i.docln.net',
      'i3.docln.net',
      'i.hako.vn',
      'i2.hako.vip',
      'i.hako.vip',
      'i2.ln.hako.vn',
    ],
    'i3.docln.net': [
      'i.docln.net',
      'i2.docln.net',
      'i.hako.vn',
      'i3.hako.vip',
      'i.hako.vip',
      'i3.ln.hako.vn',
    ],
    'i.hako.vn': [
      'i.docln.net',
      'i.ln.hako.vn',
      'i.hako.vip',
      'i2.hako.vip',
      'i3.hako.vip',
    ],
    'i.ln.hako.vn': [
      'i.docln.net',
      'i.hako.vn',
      'i.hako.vip',
      'i2.ln.hako.vn',
      'i3.ln.hako.vn',
    ],
  };

  // Cache for storing redirected URLs to avoid repeated requests
  final Map<String, String> _redirectCache = {};

  Future<void> initialize() async {
    await _httpClient.initialize();
    await _dnsService.initialize();
    await _loadDnsSettings();
  }

  Future<void> _loadDnsSettings() async {
    _isDnsEnabled = await _settingsService.isDnsEnabled();
    _dnsProvider = await _settingsService.getDnsProvider();
    _customDns = await _settingsService.getCustomDns();

    if (_isDnsEnabled) {
      print('Crawler using DNS settings: $_dnsProvider');
      if (_dnsProvider == 'Custom') {
        print('Custom DNS: $_customDns');
      } else {
        final dnsServer = SettingsService.dnsProviders[_dnsProvider] ?? '';
        print('DNS Server: $dnsServer');
      }
    }
  }

  Future<String?> _getWorkingServer() async {
    // CRITICAL FIX: Use user's selected server FIRST
    // This prevents data corruption when users change servers
    try {
      await _serverManagement.initialize();
      final userServer = _serverManagement.currentServer;
      
      debugPrint('🔧 Using user-selected server: $userServer');
      
      // Try user's server first
      final response = await _tryServers([userServer]);
      if (response != null) {
        return response;
      }
      
      debugPrint('⚠️ User server failed, trying alternatives...');
    } catch (e) {
      debugPrint('❌ Error using user server: $e');
    }
    
    // Fallback to original logic only if user's server fails
    String? workingServer = await _tryServers(servers);

    // If primary servers don't work, try alternatives
    if (workingServer == null) {
      print('Primary servers failed, trying alternative domains...');
      for (final server in servers) {
        final alternatives = alternativeServers[server] ?? [];
        workingServer = await _tryServers(alternatives);
        if (workingServer != null) {
          print('Found working alternative server: $workingServer');
          return workingServer;
        }
      }
    }

    return workingServer;
  }

  Future<String?> _tryServers(List<String> serverList) async {
    for (String server in serverList) {
      try {
        final response = await _httpClient.get(
          server,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
          },
        );

        if (response.statusCode == 200) {
          return server;
        }
      } catch (e) {
        print('Failed to connect to the server: $server. Error: $e');

        // If DNS is enabled and we're having connection issues, try with direct IP lookup
        if (_isDnsEnabled && e.toString().contains('Failed host lookup')) {
          try {
            print('Trying DNS lookup for $server');
            final serverUri = Uri.parse(server);
            String hostLookup = serverUri.host;

            // Try to resolve the IP manually using the configured DNS
            List<InternetAddress> addresses = [];
            try {
              addresses = await InternetAddress.lookup(hostLookup);
              if (addresses.isNotEmpty) {
                print('Resolved $hostLookup to ${addresses.first.address}');
                // Unfortunately, we can't directly use the IP in HTTPS requests due to certificate issues
                // But this verifies our DNS is working
              }
            } catch (dnsError) {
              print('DNS lookup failed: $dnsError');
            }
          } catch (lookupError) {
            print('Error during manual host lookup: $lookupError');
          }
        }

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

      final response = await _httpClient.get(
        workingServer,
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

      final response = await _httpClient.get(
        workingServer,
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

      final response = await _httpClient.get(server);
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

      final response = await _httpClient.get(server);

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
      final response = await _httpClient.get(url);

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

          // First try to handle the special case where rating is in HTML with small tag
          // Format in HTML: 4,96 / <small>112</small>
          final smallElement = ratingElement.querySelector('small');
          if (smallElement != null) {
            // Get the review count from the small element
            final reviewsStr = smallElement.text.trim().replaceAll(
              RegExp(r'[^0-9]'),
              '',
            );
            reviews = int.tryParse(reviewsStr);

            // Get the rating value by removing the small element text and any non-numeric chars except decimal point/comma
            String ratingStr =
                ratingText.replaceAll(smallElement.text, '').trim();

            // Remove the slash and handle comma as decimal separator
            ratingStr = ratingStr
                .replaceAll('/', '')
                .trim()
                .replaceAll(',', '.');

            // Try to parse the rating
            rating = double.tryParse(ratingStr);
          } else {
            // Check for pattern like "4.5 / 5 - 123 đánh giá"
            final ratingMatch = RegExp(
              r'(\d+[\.,]?\d*)\s*\/\s*\d+(?:\s*-\s*(\d+)\s*đánh giá)?',
            ).firstMatch(ratingText);

            if (ratingMatch != null && ratingMatch.group(1) != null) {
              // Handle comma as decimal separator
              String ratingStr = ratingMatch.group(1)!.replaceAll(',', '.');
              rating = double.tryParse(ratingStr);

              // Try to parse reviews count
              if (ratingMatch.group(2) != null) {
                reviews = int.tryParse(ratingMatch.group(2)!);
              }
            } else {
              // Try alternative pattern if the first one doesn't match
              final parts = ratingText.split('-');
              if (parts.isNotEmpty) {
                final ratingPart = parts[0].trim();
                final ratingVal = ratingPart
                    .split('/')[0]
                    .trim()
                    .replaceAll(',', '.');
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

          // Debug output for rating extraction
          print(
            'Extracted rating: $rating, reviews: $reviews from text: $ratingText',
          );
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

  Future<void> refreshSettings() async {
    await _loadDnsSettings();
    await _httpClient.updateProxySettings();
  }

  // Improve the extract cover URL method to use new optimized approach
  String _extractCoverUrl(dom.Element? coverElement) {
    if (coverElement == null) {
      return 'https://ln.hako.vn/img/nocover.jpg';
    }

    // Try to get from data-bg attribute
    String? dataBg = coverElement.attributes['data-bg'];
    if (dataBg != null && dataBg.isNotEmpty) {
      // Use the original URL directly - let Flutter's image provider handle redirects
      return dataBg;
    }

    // Try to get from background-image style
    String? style = coverElement.attributes['style'];
    if (style != null && style.contains('url(')) {
      // Extract URL manually instead of using regex
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
        // Use the original URL directly - let Flutter's image provider handle redirects
        return url;
      }
    }

    // If all else fails, return default image
    return 'https://ln.hako.vn/img/nocover.jpg';
  }

  // Process image URLs in content to prevent 404 errors
  Future<String> _processImageUrls(String html) async {
    // We'll no longer modify image URLs in the content
    // Let the browser/WebView handle redirects automatically
    return html;
  }

  // Helper method to process regex matches - not needed with new approach
  Future<String> _processMatches(
    Iterable<RegExpMatch> matches,
    String html,
  ) async {
    // We are no longer processing matches
    return html;
  }

  // Fix image URLs based on DNS settings - no longer modifying URLs
  String fixImageUrl(String url) {
    // Special case for the u6440 pattern that's causing issues
    if (url.contains('u6440-') && url.contains('lightnovel/illusts/')) {
      // For these specific files, immediately use i2.docln.net
      String host = Uri.parse(url).host;
      if (host == 'i.hako.vn') {
        String newUrl = url.replaceFirst('i.hako.vn', 'i2.docln.net');
        print('Fixing problematic u6440 image URL: $url -> $newUrl');
        return newUrl;
      } else if (host == 'i3.docln.net') {
        // If we've gotten i3.docln.net (which often has connectivity issues), try i.docln.net instead
        String newUrl = url.replaceFirst('i3.docln.net', 'i.docln.net');
        print(
          'Avoiding i3.docln.net, using i.docln.net instead: $url -> $newUrl',
        );
        return newUrl;
      }
    }

    // Simply return the original URL for other cases
    return url;
  }

  // Add a better method for following image URL redirects
  Future<String> getRedirectUrl(String originalUrl) async {
    // Simply return the original URL
    // We're letting the Flutter image provider handle redirects internally
    return originalUrl;
  }

  // Optimize image URLs with redirect detection
  Future<String> getOptimizedImageUrl(String originalUrl) async {
    // Simply return the original URL
    // We're letting the Flutter image provider handle redirects internally
    return originalUrl;
  }

  // Add a new method to fetch chapter content with optimized loading
  Future<Map<String, dynamic>> getChapterContent(
    String url,
    BuildContext context,
  ) async {
    try {
      // Make sure the URL is absolute
      if (!url.startsWith('http')) {
        final baseServer = await _getWorkingServer();
        if (baseServer == null) {
          throw Exception('No working server available');
        }
        url = url.startsWith('/') ? '$baseServer$url' : '$baseServer/$url';
      }

      print('Fetching chapter content from URL: $url');

      // Use a completer to handle the async operation properly
      final completer = Completer<Map<String, dynamic>>();

      // Process the content in a separate isolate or at least in a microtask to prevent UI freezing
      Future.microtask(() async {
        try {
          final response = await _httpClient.get(
            url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            },
          );

          if (response.statusCode != 200) {
            completer.completeError(
              Exception(
                'Failed to load chapter content: HTTP ${response.statusCode}',
              ),
            );
            return;
          }

          // PREPROCESSING: First do a quick check if content is too large
          String rawHtml = response.body;
          final contentSize = rawHtml.length;
          print('Original HTML size: $contentSize');

          // For very large content, use a more optimized approach
          Map<String, dynamic> result;
          if (contentSize > 500000) {
            // 500KB threshold
            // Use optimized processing for large content
            result = await _processLargeChapterContent(rawHtml, url);
          } else {
            // Use regular processing for normal-sized content
            result = _processChapterContent(rawHtml, url);
          }

          completer.complete(result);
        } catch (e) {
          print('Error in microtask content processing: $e');
          completer.completeError(e);
        }
      });

      // Handle timeout to prevent indefinite waiting
      return completer.future
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('Chapter content loading timed out');
              CustomToast.show(
                context,
                'Loading timed out. Content may be too large.',
              );
              return {
                'title': 'Loading Error',
                'content':
                    '<p>The chapter content is taking too long to load. It might be too large or the connection is slow.</p><p>Try again or choose a different chapter.</p>',
                'isError': true,
              };
            },
          )
          .catchError((error) {
            print('Error in chapter content loading: $error');
            CustomToast.show(context, 'Error loading chapter: $error');
            return {
              'title': 'Error',
              'content':
                  '<p>Failed to load chapter content. Please try again later.</p><p>Error: $error</p>',
              'isError': true,
            };
          });
    } catch (e) {
      print('Error in outer getChapterContent: $e');
      CustomToast.show(context, 'Error loading chapter: $e');
      return {
        'title': 'Error',
        'content':
            '<p>Failed to load chapter content. Please try again later.</p><p>Error: $e</p>',
        'isError': true,
      };
    }
  }

  // Process regular-sized chapter content
  Map<String, dynamic> _processChapterContent(String rawHtml, String url) {
    // PREPROCESSING: Aggressively remove ALL HTML comments before any parsing
    print('Processing normal-sized content');

    // SUPER SPECIFIC PATTERN REMOVAL: Handle the exact pattern from the screenshot
    rawHtml = rawHtml.replaceAll('FacebookDiscordFacebookDiscord', '');
    rawHtml = rawHtml.replaceAll(
      'body { background: inherit; } #footer { display: none; }',
      '',
    );

    // Check for patterns of concatenated social media names
    if (rawHtml.contains('Facebook') && rawHtml.contains('Discord')) {
      print('Detected social media pattern, applying specific removal');

      // Remove any lines containing both Facebook and Discord without proper spacing
      rawHtml = rawHtml.replaceAll(
        RegExp(r'.*(?:Facebook\s*Discord|Discord\s*Facebook).*\n?'),
        '',
      );

      // Also remove any CSS that might hide the footer
      rawHtml = rawHtml.replaceAll(
        RegExp(r'#footer\s*{\s*display:\s*none;\s*}'),
        '',
      );
      rawHtml = rawHtml.replaceAll(
        RegExp(r'body\s*{\s*background:\s*inherit;\s*}'),
        '',
      );
    }

    // Remove standard HTML comments
    rawHtml = _removeAllComments(rawHtml);
    print('HTML size after comment removal: ${rawHtml.length}');

    // Parse the HTML after comment removal
    final document = parser.parse(rawHtml);

    // Extract the chapter title
    String chapterTitle = '';
    final titleElement = document.querySelector('.chapter-title');
    if (titleElement != null) {
      chapterTitle = titleElement.text.trim();
    } else {
      // Alternative selectors for title
      final altTitleElement =
          document.querySelector('h1.title') ??
          document.querySelector('.rd_sd-name') ??
          document.querySelector('.title-top');
      if (altTitleElement != null) {
        chapterTitle = altTitleElement.text.trim();
      }
    }

    // Extract the chapter content
    String content = '';
    final contentElement =
        document.querySelector('.chapter-content') ??
        document.querySelector('#chapter-content') ??
        document.querySelector('.content') ??
        document.querySelector('article.content');

    if (contentElement != null) {
      // Remove any script, ad elements, and social media elements
      contentElement
          .querySelectorAll(
            'script, .ads, [id*="ads"], [class*="ads"], a[href*="discord"], a[href*="facebook"], a[href*="fb.com"], .social-links, [class*="social"]',
          )
          .forEach((e) => e.remove());

      // Extract the raw HTML content
      String contentHtml = contentElement.innerHtml;

      // Clean and format the content
      content = _cleanContent(contentHtml);

      // Final check for social media content
      if (content.toLowerCase().contains('discord') ||
          content.toLowerCase().contains('facebook') ||
          content.toLowerCase().contains('fb.com')) {
        print(
          'Social media content detected after cleaning, applying extra cleaning step',
        );

        // Apply more aggressive cleaning for social media mentions
        content = _removeSocialMediaContent(content);
      }
    }

    // Extract series information
    String seriesTitle = '';
    String seriesUrl = '';
    final seriesElement = document.querySelector('.series-name a');
    if (seriesElement != null) {
      seriesTitle = seriesElement.text.trim();
      seriesUrl = seriesElement.attributes['href'] ?? '';
    }

    // Extract navigation links
    String prevChapterUrl = '';
    String nextChapterUrl = '';
    String prevChapterTitle = '';
    String nextChapterTitle = '';

    // Check for navigation buttons
    final prevButton =
        document.querySelector('a.prev-chap') ??
        document.querySelector('[rel="prev"]') ??
        document.querySelector('.chap-prev');

    final nextButton =
        document.querySelector('a.next-chap') ??
        document.querySelector('[rel="next"]') ??
        document.querySelector('.chap-next');

    if (prevButton != null) {
      prevChapterUrl = prevButton.attributes['href'] ?? '';
      prevChapterTitle = prevButton.text.trim();
      if (prevChapterTitle.isEmpty) {
        prevChapterTitle = 'Previous Chapter';
      }
    }

    if (nextButton != null) {
      nextChapterUrl = nextButton.attributes['href'] ?? '';
      nextChapterTitle = nextButton.text.trim();
      if (nextChapterTitle.isEmpty) {
        nextChapterTitle = 'Next Chapter';
      }
    }

    return {
      'title': chapterTitle,
      'content': content,
      'seriesTitle': seriesTitle,
      'seriesUrl': seriesUrl,
      'prevChapterUrl': prevChapterUrl,
      'nextChapterUrl': nextChapterUrl,
      'prevChapterTitle': prevChapterTitle,
      'nextChapterTitle': nextChapterTitle,
    };
  }

  // Process large chapter content more efficiently
  Future<Map<String, dynamic>> _processLargeChapterContent(
    String rawHtml,
    String url,
  ) async {
    print('Processing large content with optimized approach');

    // For large content, we'll use a more direct approach to extract key elements
    // Extract just what we need before full parsing

    // Extract title using regex for better performance on large content
    String chapterTitle = '';
    final titleRegex = RegExp(
      r'<h1[^>]*class="chapter-title"[^>]*>(.*?)</h1>',
      dotAll: true,
    );
    final titleMatch = titleRegex.firstMatch(rawHtml);
    if (titleMatch != null && titleMatch.group(1) != null) {
      chapterTitle = _cleanTextContent(titleMatch.group(1)!);
    } else {
      // Try alternative title patterns
      final altTitleRegex = RegExp(
        r'<h1[^>]*class="title"[^>]*>(.*?)</h1>',
        dotAll: true,
      );
      final altTitleMatch = altTitleRegex.firstMatch(rawHtml);
      if (altTitleMatch != null && altTitleMatch.group(1) != null) {
        chapterTitle = _cleanTextContent(altTitleMatch.group(1)!);
      }
    }

    // Extract main content div using regex
    String content = '';
    String contentHtml = '';
    final contentRegex = RegExp(
      r'<div[^>]*class="chapter-content"[^>]*>(.*?)</div>',
      dotAll: true,
    );
    final contentMatch = contentRegex.firstMatch(rawHtml);

    if (contentMatch != null && contentMatch.group(1) != null) {
      contentHtml = contentMatch.group(1)!;
    } else {
      // Try alternative content patterns
      final altContentRegex = RegExp(
        r'<div[^>]*id="chapter-content"[^>]*>(.*?)</div>',
        dotAll: true,
      );
      final altContentMatch = altContentRegex.firstMatch(rawHtml);
      if (altContentMatch != null && altContentMatch.group(1) != null) {
        contentHtml = altContentMatch.group(1)!;
      } else {
        // One more try with generic content class
        final genericContentRegex = RegExp(
          r'<div[^>]*class="content"[^>]*>(.*?)</div>',
          dotAll: true,
        );
        final genericContentMatch = genericContentRegex.firstMatch(rawHtml);
        if (genericContentMatch != null &&
            genericContentMatch.group(1) != null) {
          contentHtml = genericContentMatch.group(1)!;
        }
      }
    }

    // Clean content more efficiently
    if (contentHtml.isNotEmpty) {
      // Remove social media and ads sections first
      contentHtml = _quickRemoveSocialMedia(contentHtml);

      // Now process in chunks to avoid UI freezes
      content = await _processContentChunks(contentHtml);
    }

    // Extract navigation links with regex
    String prevChapterUrl = '';
    String nextChapterUrl = '';
    String prevChapterTitle = 'Previous Chapter';
    String nextChapterTitle = 'Next Chapter';

    // Find prev link
    final prevRegex = RegExp(
      r'<a[^>]*class="prev-chap"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final prevMatch = prevRegex.firstMatch(rawHtml);
    if (prevMatch != null) {
      prevChapterUrl = prevMatch.group(1) ?? '';
      final prevTitleRaw = prevMatch.group(2) ?? '';
      if (prevTitleRaw.isNotEmpty) {
        prevChapterTitle = _cleanTextContent(prevTitleRaw);
      }
    }

    // Find next link
    final nextRegex = RegExp(
      r'<a[^>]*class="next-chap"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final nextMatch = nextRegex.firstMatch(rawHtml);
    if (nextMatch != null) {
      nextChapterUrl = nextMatch.group(1) ?? '';
      final nextTitleRaw = nextMatch.group(2) ?? '';
      if (nextTitleRaw.isNotEmpty) {
        nextChapterTitle = _cleanTextContent(nextTitleRaw);
      }
    }

    // Extract series info
    String seriesTitle = '';
    String seriesUrl = '';
    final seriesRegex = RegExp(
      r'<span[^>]*class="series-name"[^>]*>.*?<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final seriesMatch = seriesRegex.firstMatch(rawHtml);
    if (seriesMatch != null) {
      seriesUrl = seriesMatch.group(1) ?? '';
      seriesTitle =
          seriesMatch.group(2) != null
              ? _cleanTextContent(seriesMatch.group(2)!)
              : '';
    }

    return {
      'title': chapterTitle,
      'content': content,
      'seriesTitle': seriesTitle,
      'seriesUrl': seriesUrl,
      'prevChapterUrl': prevChapterUrl,
      'nextChapterUrl': nextChapterUrl,
      'prevChapterTitle': prevChapterTitle,
      'nextChapterTitle': nextChapterTitle,
      'isLargeContent': true,
    };
  }

  // Process content in chunks to prevent UI blocking
  Future<String> _processContentChunks(String contentHtml) async {
    // Break content into manageable chunks
    const int chunkSize = 15000; // 15KB chunks
    List<String> results = [];

    if (contentHtml.length <= chunkSize) {
      return _cleanContent(contentHtml);
    }

    // Split content into paragraphs first for cleaner chunking
    final paragraphs =
        RegExp(r'<p[^>]*>.*?</p>', dotAll: true)
            .allMatches(contentHtml)
            .map((m) => m.group(0) ?? '')
            .where((p) => p.isNotEmpty)
            .toList();

    // If no paragraphs found, fall back to simple chunking
    if (paragraphs.isEmpty) {
      int chunks = (contentHtml.length / chunkSize).ceil();
      for (int i = 0; i < chunks; i++) {
        int start = i * chunkSize;
        int end = (i + 1) * chunkSize;
        if (end > contentHtml.length) end = contentHtml.length;

        String chunk = contentHtml.substring(start, end);
        // Process each chunk with a delay to prevent UI freezing
        final processed = await Future.microtask(() => _cleanContent(chunk));
        results.add(processed);

        // Small delay to let UI breathe
        await Future.delayed(Duration(milliseconds: 1));
      }
    } else {
      // Process by paragraph groups
      List<String> currentChunk = [];
      int currentSize = 0;

      for (final paragraph in paragraphs) {
        currentChunk.add(paragraph);
        currentSize += paragraph.length;

        if (currentSize >= chunkSize) {
          // Process this chunk
          String chunkContent = currentChunk.join('\n');
          final processed = await Future.microtask(
            () => _cleanContent(chunkContent),
          );
          results.add(processed);

          // Reset for next chunk
          currentChunk = [];
          currentSize = 0;

          // Small delay to let UI breathe
          await Future.delayed(Duration(milliseconds: 1));
        }
      }

      // Process any remaining paragraphs
      if (currentChunk.isNotEmpty) {
        String chunkContent = currentChunk.join('\n');
        final processed = await Future.microtask(
          () => _cleanContent(chunkContent),
        );
        results.add(processed);
      }
    }

    return results.join('\n');
  }

  // Quick clean of text content (removes HTML tags)
  String _cleanTextContent(String html) {
    // Remove HTML tags
    String text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Trim whitespace
    return text.trim();
  }

  // Quick social media removal without full parsing
  String _quickRemoveSocialMedia(String html) {
    // Remove common social media patterns
    final patterns = [
      r'<div[^>]*>.*?(?:Facebook|Discord).*?</div>',
      r'<p[^>]*>.*?(?:Facebook|Discord).*?</p>',
      r'<div[^>]*class="[^"]*social[^"]*"[^>]*>.*?</div>',
      r'<div[^>]*class="[^"]*footer[^"]*"[^>]*>.*?</div>',
      r'<div[^>]*class="[^"]*connect[^"]*"[^>]*>.*?</div>',
      r'<div[^>]*class="[^"]*follow[^"]*"[^>]*>.*?</div>',
    ];

    String result = html;
    for (final pattern in patterns) {
      result = result.replaceAll(
        RegExp(pattern, dotAll: true, caseSensitive: false),
        '',
      );
    }

    return result;
  }

  // Helper method to clean HTML content
  String _cleanContent(String html) {
    // Remove social media links first
    html = html.replaceAll(
      RegExp(
        r'<div[^>]*>.*?(?:Facebook|Discord|fb\.com).*?</div>',
        dotAll: true,
      ),
      '',
    );
    html = html.replaceAll(
      RegExp(r'<a[^>]*(?:discord|facebook|fb\.com)[^>]*>.*?</a>', dotAll: true),
      '',
    );

    // Save image tags to restore later
    final Map<String, String> imageReplacements = {};
    final imageMatches = RegExp(
      r'<img\s+[^>]*src\s*=\s*"([^"]*)"[^>]*>',
      dotAll: true,
    ).allMatches(html);
    int imageCounter = 0;

    for (final match in imageMatches) {
      final fullTag = match.group(0);
      final srcUrl = match.group(1);
      if (fullTag != null && srcUrl != null) {
        // Fix the image URL in place
        String fixedUrl = fixImageUrl(srcUrl);
        String updatedTag = fullTag.replaceFirst(srcUrl, fixedUrl);

        final placeholder = '___IMAGE_PLACEHOLDER_${imageCounter++}___';
        imageReplacements[placeholder] = updatedTag;
        html = html.replaceFirst(fullTag, placeholder);
      }
    }

    // Also handle single quote image tags
    final singleQuoteImageMatches = RegExp(
      r"<img\s+[^>]*src\s*=\s*'([^']*)'[^>]*>",
      dotAll: true,
    ).allMatches(html);
    for (final match in singleQuoteImageMatches) {
      final fullTag = match.group(0);
      final srcUrl = match.group(1);
      if (fullTag != null && srcUrl != null) {
        // Fix the image URL in place
        String fixedUrl = fixImageUrl(srcUrl);
        String updatedTag = fullTag.replaceFirst(srcUrl, fixedUrl);

        final placeholder = '___IMAGE_PLACEHOLDER_${imageCounter++}___';
        imageReplacements[placeholder] = updatedTag;
        html = html.replaceFirst(fullTag, placeholder);
      }
    }

    // Fix raw HTML tags appearing in the content
    // Replace <p id="X"> tags with regular <p> tags - handle double quotes
    html = html.replaceAll(RegExp(r'<p\s+id\s*=\s*"[^"]*"[^>]*>'), '<p>');
    // Also handle single quotes
    html = html.replaceAll(RegExp(r"<p\s+id\s*=\s*'[^']*'[^>]*>"), '<p>');

    // Remove excessive whitespace and newlines
    html = html.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Handle special case where the HTML might be double-encoded
    if (html.contains('&lt;p') || html.contains('&lt;div')) {
      html = html.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    }

    // Convert div and span elements to paragraphs for better reading
    html = html.replaceAllMapped(
      RegExp(r'<div[^>]*>(.*?)</div>', dotAll: true),
      (match) => '<p>${match.group(1)}</p>',
    );

    // Also handle span elements
    html = html.replaceAllMapped(
      RegExp(r'<span[^>]*>(.*?)</span>', dotAll: true),
      (match) => match.group(1) ?? '',
    );

    // Convert line breaks to paragraphs
    html = html.replaceAll('<br>', '</p><p>');
    html = html.replaceAll('<br/>', '</p><p>');
    html = html.replaceAll('<br />', '</p><p>');

    // Fix empty paragraphs
    html = html.replaceAll(RegExp(r'<p>\s*</p>'), '');

    // Ensure paragraphs for each line
    final lines =
        html.split('\n').where((line) => line.trim().isNotEmpty).toList();
    html = lines
        .map((line) {
          if (!line.trim().startsWith('<') && !line.trim().endsWith('>')) {
            return '<p>$line</p>';
          }
          return line;
        })
        .join('\n');

    // Remove any standalone '$1' artifacts from regex replacements
    html = html.replaceAll(RegExp(r'<p>\s*\$\d+\s*</p>'), '');
    html = html.replaceAll(RegExp(r'\s\$\d+\s'), ' ');

    // Remove any remaining text containing Discord or Facebook
    html = html.replaceAll(
      RegExp(
        r'<p>[^<]*(?:Discord|Facebook|fb\.com)[^<]*</p>',
        caseSensitive: false,
      ),
      '',
    );

    // Restore image tags
    imageReplacements.forEach((placeholder, imageTag) {
      html = html.replaceAll(placeholder, imageTag);
    });

    return html;
  }

  // Helper method for aggressive removal of social media content
  String _removeSocialMediaContent(String html) {
    // Remove any paragraph containing social media keywords
    final List<String> socialKeywords = [
      'discord',
      'facebook',
      'fb.com',
      'social',
      'follow us',
      'join us',
    ];

    for (final keyword in socialKeywords) {
      final pattern = '<p>[^<]*' + keyword + '[^<]*</p>';
      html = html.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // Remove blocks of text with multiple mentions of social media
    html = html.replaceAll(
      RegExp(
        r'<div[^>]*>(?:(?!<div).)*?(discord|facebook|fb\.com)(?:(?!<div).)*?</div>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // Remove rows or flex containers that might contain social media links
    html = html.replaceAll(
      RegExp(
        r'<div[^>]*(?:flex|row|space-x)[^>]*>.*?(?:discord|facebook|fb\.com).*?</div>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // Remove the footer section which might contain social links
    html = html.replaceAll(
      RegExp(
        r'<div[^>]*(?:footer|bottom)[^>]*>.*?</div>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // Remove any classes commonly containing social elements
    html = html.replaceAll(
      RegExp(
        r'<div[^>]*class\s*=\s*"[^"]*(?:social|connect|follow)[^"]*"[^>]*>.*?</div>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    return html;
  }

  // New helper method to aggressively remove ALL HTML comments
  String _removeAllComments(String html) {
    // First pass: Basic HTML comment removal
    String cleanedHtml = html;

    // Handle different forms of comments
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'<!--[\s\S]*?-->', dotAll: true),
      '',
    );

    // Handle unclosed comments (which might continue until end of file)
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'<!--[\s\S]*?($|-->)', dotAll: true),
      '',
    );

    // Remove any CSS/JS style comments
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'/\*[\s\S]*?\*/', dotAll: true),
      '',
    );

    // Remove single line comments
    cleanedHtml = cleanedHtml.replaceAll(RegExp(r'//.*?(\n|$)'), '');

    // Remove any script tags that might contain comments or scripts
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'<script[\s\S]*?</script>', dotAll: true),
      '',
    );

    // Remove any style tags that might contain comments
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'<style[\s\S]*?</style>', dotAll: true),
      '',
    );

    // Handle the specific pattern shown in the example
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(r'Facebook\s*Discord\s*Facebook\s*Discord'),
      '',
    );

    // Additional stage: Remove any partial comments that might remain
    cleanedHtml = cleanedHtml.replaceAll('<!--', '');
    cleanedHtml = cleanedHtml.replaceAll('-->', '');

    // Pre-emptively remove social media elements before parsing
    // Discord related
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(
        r'<[^>]*discord[^>]*>[\s\S]*?</[^>]*>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Facebook related
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(
        r'<[^>]*(?:facebook|fb\.com)[^>]*>[\s\S]*?</[^>]*>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Handle divs with social media related classes or IDs
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(
        r'<div[^>]*(?:class|id)\s*=\s*"[^"]*(?:social|follow|connect|share)[^"]*"[^>]*>[\s\S]*?</div>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Remove divs containing "Discord" or "Facebook" text
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(
        r'<div[^>]*>[\s\S]*?(?:Discord|Facebook|fb\.com)[\s\S]*?</div>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Remove any flex or row containers that often contain social links
    cleanedHtml = cleanedHtml.replaceAll(
      RegExp(
        r'<div[^>]*(?:flex|row|space-x-3|mt-10|justify-center)[^>]*>[\s\S]*?</div>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    return cleanedHtml;
  }

  // Add a new method to fetch comments
  Future<List<Map<String, dynamic>>> getChapterComments(
    String url,
    BuildContext context,
  ) async {
    try {
      // Extract the chapter ID and novel ID from the URL if needed for AJAX requests
      String chapterId = '';
      String novelId = '';

      // Parse the URL to extract needed identifiers
      RegExp urlPattern = RegExp(r'/truyen/(\d+)-[^/]+/c(\d+)-');
      Match? match = urlPattern.firstMatch(url);
      if (match != null && match.groupCount >= 2) {
        novelId = match.group(1) ?? '';
        chapterId = match.group(2) ?? '';
        print('Extracted novelId: $novelId, chapterId: $chapterId');
      } else {
        // Use direct URL approach as fallback
        print('Could not extract IDs from URL, using direct approach');
      }

      // Check if this is a pagination request (called with page parameter)
      if (url.contains('page=')) {
        // Extract the page number
        RegExp pagePattern = RegExp(r'page=(\d+)');
        Match? pageMatch = pagePattern.firstMatch(url);
        int page = pageMatch != null ? int.parse(pageMatch.group(1) ?? '1') : 1;

        // Use AJAX pagination endpoint instead
        String baseUrl = '';
        if (url.startsWith('http')) {
          Uri uri = Uri.parse(url);
          baseUrl = '${uri.scheme}://${uri.host}';
        } else {
          // Try to determine the base URL from a working server
          baseUrl = await _getWorkingServer() ?? 'https://ln.hako.vn';
        }

        // First, we need to get a valid CSRF token by loading the main page
        final chapterUrl = url.split('?')[0];
        final tokenResponse = await _httpClient.get(
          chapterUrl,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          },
        );

        // Extract CSRF token from the response
        String csrfToken = '';
        if (tokenResponse.statusCode == 200) {
          final htmlDoc = parser.parse(tokenResponse.body);
          final metaTag = htmlDoc.querySelector('meta[name="csrf-token"]');
          csrfToken = metaTag?.attributes['content'] ?? '';
          print('Found CSRF token: ${csrfToken.isNotEmpty ? "Yes" : "No"}');
        }

        // Get cookies from the response
        Map<String, String> cookieMap = {};
        String rawCookies = tokenResponse.headers['set-cookie'] ?? '';

        // Process all cookies from the response
        if (rawCookies.isNotEmpty) {
          final cookieParts = rawCookies.split(',');
          for (final cookiePart in cookieParts) {
            final cookieString = cookiePart.trim();
            if (cookieString.isNotEmpty) {
              final mainPart = cookieString.split(';').first.trim();
              if (mainPart.contains('=')) {
                final keyValue = mainPart.split('=');
                if (keyValue.length == 2) {
                  final key = keyValue[0].trim();
                  final value = keyValue[1].trim();
                  cookieMap[key] = value;
                }
              }
            }
          }
        }

        // Also check for XSRF-TOKEN in the cookies - many Laravel apps use this
        final xsrfTokenFromCookie = cookieMap['XSRF-TOKEN'] ?? '';
        if (xsrfTokenFromCookie.isNotEmpty && csrfToken.isEmpty) {
          // Decode URL-encoded token
          try {
            csrfToken = Uri.decodeComponent(xsrfTokenFromCookie);
            // Some Laravel applications encode the token twice
            if (csrfToken.contains('%')) {
              csrfToken = Uri.decodeComponent(csrfToken);
            }
          } catch (e) {
            print('Error decoding XSRF token: $e');
            csrfToken = xsrfTokenFromCookie;
          }
        }

        // Build cookie header value from map
        final cookieHeader = cookieMap.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
        print('Prepared cookies: ${cookieHeader.isNotEmpty ? "Yes" : "No"}');

        // Extract the type_id (chapter ID) from the URL for AJAX request
        String typeId = '';
        RegExp chapterPattern = RegExp(r'/c(\d+)-');
        Match? chapterMatch = chapterPattern.firstMatch(chapterUrl);

        if (chapterMatch != null && chapterMatch.groupCount >= 1) {
          typeId = chapterMatch.group(1) ?? '';
          print('Extracted typeId for request: $typeId');
        } else {
          typeId = chapterId; // Fallback to previously extracted chapter ID
        }

        // Use the AJAX endpoint for pagination
        url = '$baseUrl/comment/ajax_paging';

        // Make a POST request to the AJAX endpoint with the correct parameters
        final response = await _httpClient.post(
          url,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': baseUrl,
            'Referer': chapterUrl,
            'X-CSRF-TOKEN': csrfToken,
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          body:
              '_token=${Uri.encodeComponent(csrfToken)}&type=chapter&type_id=$typeId&page=$page',
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to load comments: HTTP ${response.statusCode}',
          );
        }

        // Print raw response for debugging
        print(
          'Raw AJAX response body: ${response.body.substring(0, math.min(1000, response.body.length))}...',
        );

        // Parse the JSON response
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['html'] != null) {
          // Print a sample of the HTML for debugging
          print(
            'HTML content sample: ${jsonResponse['html'].substring(0, math.min(500, jsonResponse['html'].length))}...',
          );

          // Parse the HTML content from the JSON response
          final document = parser.parse(jsonResponse['html']);
          return _extractCommentsFromDocument(document, url);
        } else {
          throw Exception('Invalid AJAX response format');
        }
      } else {
        // Initial load - use direct URL approach
        if (!url.contains('?comment_id=')) {
          // Ensure we're using the base chapter URL without comment parameters
          url = url.split('?')[0];
        }

        print('Fetching comments from URL: $url');

        final response = await _httpClient.get(
          url,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          },
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to load comments: HTTP ${response.statusCode}',
          );
        }

        // Print raw response for debugging
        print(
          'Raw direct URL response sample: ${response.body.substring(0, math.min(1000, response.body.length))}...',
        );

        final document = parser.parse(response.body);
        return _extractCommentsFromDocument(document, url);
      }
    } catch (e) {
      print('Error fetching comments: $e');
      CustomToast.show(context, 'Error loading comments: $e');
      return [];
    }
  }

  // Helper method to extract comments from HTML document
  List<Map<String, dynamic>> _extractCommentsFromDocument(
    dom.Document document,
    String url,
  ) {
    // Get current page number from URL
    int currentPage = _extractPageNumberFromUrl(url);

    // Print document information for debugging
    print('Document body length: ${document.body?.text.length ?? 0}');
    print(
      'Document tags found: ${document.querySelectorAll('main, div, section').length}',
    );

    // Check if the document has the "no comments" message using text content
    bool hasNoCommentsMessage = false;
    final bodyText = document.body?.text ?? '';

    // Check if the text contains the Vietnamese "no comments" message
    if (bodyText.contains('Không có bình luận nào') ||
        bodyText.contains('Chưa có bình luận') ||
        bodyText.contains('Be the first to comment')) {
      hasNoCommentsMessage = true;
    }

    // If we found a "no comments" message, return an empty list with a special flag
    if (hasNoCommentsMessage) {
      // Return a special comment that indicates no comments were found
      return [
        {
          'id': 'empty',
          'user': {'name': '', 'image': '', 'url': '', 'badges': []},
          'content': 'Không có bình luận nào',
          'timestamp': '',
          'rawTimestamp': '',
          'likes': '',
          'isEmptyPage': true, // Special flag to indicate an empty page
          'currentPage': currentPage,
          'hasMorePages': false,
          'nextPageUrl': '',
          'hasPrevPage': currentPage > 1,
          'prevPageUrl': _constructPrevPageUrl(url, currentPage),
        },
      ];
    }

    // Find comments section in the document
    var commentsSection = document.querySelector('main.ln-comment-body');
    if (commentsSection == null) {
      print('No comments section found in the HTML');

      // Try alternative selectors and log what we find
      final alternativeCommentSections = document.querySelectorAll(
        '.ln-comment, #comments, .comments-section, .comment-list',
      );
      if (alternativeCommentSections.isNotEmpty) {
        print(
          'Found alternative comment sections: ${alternativeCommentSections.length}',
        );
        for (
          var i = 0;
          i < math.min(alternativeCommentSections.length, 3);
          i++
        ) {
          print(
            'Alternative section ${i + 1} classes: ${alternativeCommentSections[i].classes.join(', ')}',
          );
          print(
            'Alternative section ${i + 1} content: ${alternativeCommentSections[i].text.substring(0, math.min(alternativeCommentSections[i].text.length, 100))}...',
          );
        }
        commentsSection = alternativeCommentSections.first;
      }
    }

    List<Map<String, dynamic>> comments = [];
    // Set to track comment IDs we've already processed to avoid duplicates
    Set<String> processedCommentIds = {};

    // Track comment content to detect duplicates even with different IDs
    Set<String> processedContentHashes = {};

    // Try to get comment groups which might contain both top-level comments and replies
    final commentGroups =
        commentsSection?.querySelectorAll('.ln-comment-group') ?? [];
    print('Found ${commentGroups.length} comment groups');

    if (commentGroups.isEmpty) {
      // Fallback to direct comment items if no groups are found
      final commentItems =
          commentsSection?.querySelectorAll('.ln-comment-item') ?? [];
      print('Found ${commentItems.length} direct comment items');

      if (commentItems.isEmpty) {
        // If still no items, try an even more generic approach
        print('No standard comment items found, trying generic approach');
        final allPossibleComments = document.querySelectorAll(
          '[class*="comment"], [id*="comment"], .ln-comment-content, .flex.gap-1',
        );
        print('Found ${allPossibleComments.length} possible comment elements');

        for (final element in allPossibleComments) {
          // Check if this is likely a standalone comment (has appropriate content and structure)
          final hasUserSection =
              element.querySelector('img') != null; // Has avatar
          final hasContent =
              element.text.trim().length > 10; // Has reasonable text

          if (hasUserSection && hasContent) {
            final comment = _extractCommentData(element, url);
            final commentId = comment['id'] as String;
            final commentContent = comment['content'] as String;

            // Generate a content hash using username + content to detect duplicate content
            final userName =
                (comment['user'] as Map<String, dynamic>)['name'] as String;
            final contentHash =
                '$userName-${commentContent.substring(0, math.min(50, commentContent.length))}';

            // Only add if not already processed (by ID or content)
            if (!processedCommentIds.contains(commentId) &&
                !processedContentHashes.contains(contentHash)) {
              processedCommentIds.add(commentId);
              processedContentHashes.add(contentHash);
              comments.add(comment);
            } else {
              print(
                'Skipping duplicate comment: $commentId (content hash: $contentHash)',
              );
            }
          }
        }
      } else {
        // Process all comments as top-level (no replies)
        for (final commentItem in commentItems) {
          final comment = _extractCommentData(commentItem, url);
          final commentId = comment['id'] as String;
          final commentContent = comment['content'] as String;

          // Generate a content hash using username + content to detect duplicate content
          final userName =
              (comment['user'] as Map<String, dynamic>)['name'] as String;
          final contentHash =
              '$userName-${commentContent.substring(0, math.min(50, commentContent.length))}';

          // Only add if not already processed
          if (!processedCommentIds.contains(commentId) &&
              !processedContentHashes.contains(contentHash)) {
            processedCommentIds.add(commentId);
            processedContentHashes.add(contentHash);
            comments.add(comment);
          } else {
            print(
              'Skipping duplicate comment: $commentId (content hash: $contentHash)',
            );
          }
        }
      }
    } else {
      // Process groups which may contain parent comments and replies
      for (final group in commentGroups) {
        // Get the parent comment in this group - avoid complex :not() selector
        // Instead, get the first direct child .ln-comment-item that's not inside a .ln-comment-reply
        final allItems = group.querySelectorAll('.ln-comment-item');
        dom.Element? parentCommentItem;

        // First try to find a direct child of the group
        for (final item in allItems) {
          // Check if this item is a direct child or inside another container
          final parentNode = item.parent;
          if (parentNode != null && parentNode == group ||
              (parentNode?.classes?.isEmpty == true &&
                  parentNode?.parent == group)) {
            // This is likely the parent comment
            parentCommentItem = item;
            break;
          }
        }

        // If not found, just use the first item as parent
        if (parentCommentItem == null && allItems.isNotEmpty) {
          parentCommentItem = allItems.first;
        }

        if (parentCommentItem != null) {
          // Extract parent comment data
          final parentComment = _extractCommentData(parentCommentItem, url);
          final parentId = parentComment['id'] as String;
          final parentContent = parentComment['content'] as String;

          // Generate a content hash for the parent comment
          final parentUserName =
              (parentComment['user'] as Map<String, dynamic>)['name'] as String;
          final parentContentHash =
              '$parentUserName-${parentContent.substring(0, math.min(50, parentContent.length))}';

          // Skip if we've already processed this comment
          if (processedCommentIds.contains(parentId) ||
              processedContentHashes.contains(parentContentHash)) {
            print(
              'Skipping duplicate parent comment: $parentId (content hash: $parentContentHash)',
            );
            continue;
          }

          processedCommentIds.add(parentId);
          processedContentHashes.add(parentContentHash);

          // Find all replies in this group
          final replySection = group.querySelector('.ln-comment-reply');
          if (replySection != null) {
            final replyItems = replySection.querySelectorAll(
              '.ln-comment-item',
            );
            print(
              'Found ${replyItems.length} replies for comment ${parentComment['id']}',
            );

            List<Map<String, dynamic>> replies = [];

            // Extract data from each reply
            for (final replyItem in replyItems) {
              final reply = _extractCommentData(replyItem, url);
              final replyId = reply['id'] as String;
              final replyContent = reply['content'] as String;

              // Generate a content hash for the reply
              final replyUserName =
                  (reply['user'] as Map<String, dynamic>)['name'] as String;
              final replyContentHash =
                  '$replyUserName-${replyContent.substring(0, math.min(50, replyContent.length))}';

              // Skip if we've already processed this reply
              if (processedCommentIds.contains(replyId) ||
                  processedContentHashes.contains(replyContentHash)) {
                print(
                  'Skipping duplicate reply: $replyId (content hash: $replyContentHash)',
                );
                continue;
              }

              processedCommentIds.add(replyId);
              processedContentHashes.add(replyContentHash);
              reply['parentId'] = parentComment['id']; // Set parent ID
              replies.add(reply);
            }

            // Store replies to be associated with parent later
            if (replies.isNotEmpty) {
              parentComment['replies'] = replies;
            }
          } else {
            // Try alternative approach: find replies by looking for items after the parent
            bool foundParent = false;
            List<Map<String, dynamic>> replies = [];

            // Go through all comment items in the group and collect those after the parent
            for (final item in allItems) {
              if (item == parentCommentItem) {
                foundParent = true;
                continue;
              }

              // If we already found the parent and this is another item, treat it as a reply
              if (foundParent) {
                final reply = _extractCommentData(item, url);
                final replyId = reply['id'] as String;

                // Skip if we've already processed this reply
                if (processedCommentIds.contains(replyId)) {
                  continue;
                }

                processedCommentIds.add(replyId);
                reply['parentId'] = parentComment['id']; // Set parent ID
                replies.add(reply);
              }
            }

            // Store replies
            if (replies.isNotEmpty) {
              print(
                'Found ${replies.length} alternative replies for comment ${parentComment['id']}',
              );
              parentComment['replies'] = replies;
            }
          }

          comments.add(parentComment);
        }
      }
    }

    // If we didn't find any comments through structured extraction,
    // try a more aggressive fallback approach
    if (comments.isEmpty) {
      print(
        'No comments found with standard selectors, trying fallback extraction',
      );
      final allCommentElements = document.querySelectorAll(
        '[id^="comment-"], [class*="comment-item"]',
      );

      for (final element in allCommentElements) {
        try {
          // Basic extraction of just text and info we can find
          final id =
              element.id.isNotEmpty
                  ? element.id
                  : 'comment-${comments.length + 1}';
          final content = element.text.trim();

          if (content.isNotEmpty) {
            comments.add({
              'id': id,
              'user': {'name': 'Unknown', 'image': '', 'url': '', 'badges': []},
              'content': content,
              'timestamp': '',
              'rawTimestamp': '',
              'likes': '',
            });
          }
        } catch (e) {
          print('Error in fallback extraction: $e');
        }
      }
    }

    // Add pagination info to the last comment
    if (comments.isNotEmpty) {
      // Check for pagination
      final paginationDiv = document.querySelector('.ln-comment-page');
      bool hasMorePages = false;
      String nextPageUrl = '';
      bool hasPrevPage = false;
      String prevPageUrl = '';

      if (paginationDiv != null) {
        // Extract pagination info from the DOM
        final paginationInfo = _extractPaginationInfo(
          paginationDiv,
          url,
          currentPage,
        );
        hasMorePages = paginationInfo['hasMorePages'] as bool;
        nextPageUrl = paginationInfo['nextPageUrl'] as String;
        hasPrevPage = paginationInfo['hasPrevPage'] as bool;
        prevPageUrl = paginationInfo['prevPageUrl'] as String;
        currentPage = paginationInfo['currentPage'] as int;
      } else {
        // Fallback: check if there's any link that seems like pagination
        final nextLink = document.querySelector(
          'a[href*="page="], a[href*="?page"], .next, .pagination a',
        );
        if (nextLink != null) {
          hasMorePages = true;
          nextPageUrl = nextLink.attributes['href'] ?? '';

          // Make sure we have a properly formatted URL
          if (nextPageUrl.isNotEmpty && !nextPageUrl.startsWith('http')) {
            // Extract base URL from the original URL
            String baseUrl = '';
            if (url.startsWith('http')) {
              Uri uri = Uri.parse(url);
              baseUrl = '${uri.scheme}://${uri.host}';
              if (!nextPageUrl.startsWith('/')) {
                nextPageUrl = '/$nextPageUrl';
              }
              nextPageUrl = '$baseUrl$nextPageUrl';
            }
          }
        }

        // If we're not on page 1, enable prev page
        if (currentPage > 1) {
          hasPrevPage = true;
          prevPageUrl = _constructPrevPageUrl(url, currentPage);
        }
      }

      // Update the last comment with pagination info
      comments.last['hasMorePages'] = hasMorePages;
      comments.last['nextPageUrl'] = nextPageUrl;
      comments.last['hasPrevPage'] = hasPrevPage;
      comments.last['prevPageUrl'] = prevPageUrl;
      comments.last['currentPage'] = currentPage;
    }

    return comments;
  }

  // Helper to extract pagination information
  Map<String, dynamic> _extractPaginationInfo(
    dom.Element paginationDiv,
    String url,
    int currentPage,
  ) {
    bool hasMorePages = false;
    String nextPageUrl = '';
    bool hasPrevPage = false;
    String prevPageUrl = '';

    // Extract current page from next/prev links
    final prevButton = paginationDiv.querySelector('.paging_item.prev');
    final nextButton = paginationDiv.querySelector('.paging_item.next');

    // Check if next button exists and is not disabled
    if (nextButton != null && !nextButton.classes.contains('disabled')) {
      hasMorePages = true;
      nextPageUrl = nextButton.attributes['href'] ?? '';

      // Make sure we have a properly formatted URL
      if (nextPageUrl.isNotEmpty && !nextPageUrl.startsWith('http')) {
        // Extract base URL from the original URL
        String baseUrl = '';
        if (url.startsWith('http')) {
          Uri uri = Uri.parse(url);
          baseUrl = '${uri.scheme}://${uri.host}';
          if (!nextPageUrl.startsWith('/')) {
            nextPageUrl = '/$nextPageUrl';
          }
          nextPageUrl = '$baseUrl$nextPageUrl';
        }
      }

      // Extract page number from URL if we couldn't determine it otherwise
      if (currentPage <= 1) {
        final pageMatch = RegExp(r'page=(\d+)').firstMatch(nextPageUrl);
        if (pageMatch != null && pageMatch.group(1) != null) {
          // Current page is one less than next page
          currentPage = int.parse(pageMatch.group(1)!) - 1;
        }
      }
    }

    // Check if prev button exists and is not disabled
    if (prevButton != null && !prevButton.classes.contains('disabled')) {
      hasPrevPage = true;
      prevPageUrl = prevButton.attributes['href'] ?? '';

      // Make sure we have a properly formatted URL
      if (prevPageUrl.isNotEmpty && !prevPageUrl.startsWith('http')) {
        // Extract base URL from the original URL
        String baseUrl = '';
        if (url.startsWith('http')) {
          Uri uri = Uri.parse(url);
          baseUrl = '${uri.scheme}://${uri.host}';
          if (!prevPageUrl.startsWith('/')) {
            prevPageUrl = '/$prevPageUrl';
          }
          prevPageUrl = '$baseUrl$prevPageUrl';
        }
      }

      // If we couldn't determine current page from next link, try from prev link
      if (currentPage <= 1 && prevPageUrl.isNotEmpty) {
        final pageMatch = RegExp(r'page=(\d+)').firstMatch(prevPageUrl);
        if (pageMatch != null && pageMatch.group(1) != null) {
          // Current page is one more than prev page
          currentPage = int.parse(pageMatch.group(1)!) + 1;
        }
      }
    } else if (prevButton != null && prevButton.classes.contains('disabled')) {
      // If prev is disabled, we're on page 1
      currentPage = 1;
    }

    // If there's text in the pagination that indicates the page number
    final paginationText = paginationDiv.text;
    final explicitPageMatch = RegExp(
      r'Trang\s+(\d+)',
    ).firstMatch(paginationText);
    if (explicitPageMatch != null && explicitPageMatch.group(1) != null) {
      currentPage = int.parse(explicitPageMatch.group(1)!);
    }

    return {
      'hasMorePages': hasMorePages,
      'nextPageUrl': nextPageUrl,
      'hasPrevPage': hasPrevPage,
      'prevPageUrl': prevPageUrl,
      'currentPage': currentPage,
    };
  }

  // Helper to extract comment data from a comment element
  Map<String, dynamic> _extractCommentData(
    dom.Element commentItem,
    String url,
  ) {
    // Extract comment ID - ensure we get a unique ID to avoid duplicates
    String commentId = '';

    // First try to get ID from element attributes
    if (commentItem.id.isNotEmpty) {
      commentId = commentItem.id;
    } else if (commentItem.attributes.containsKey('data-comment')) {
      commentId = commentItem.attributes['data-comment'] ?? '';
    } else {
      // Try to extract ID from href if available (often contains the comment ID)
      final idLink = commentItem.querySelector(
        'a[href*="comment_id="], a[href*="#ln-comment-"]',
      );
      if (idLink != null) {
        final href = idLink.attributes['href'] ?? '';

        // Try to extract ID from href with regex
        final idMatch = RegExp(
          r'comment_id=(\d+)|#ln-comment-(\d+)',
        ).firstMatch(href);
        if (idMatch != null) {
          commentId = idMatch.group(1) ?? idMatch.group(2) ?? '';
        }
      }
    }

    // If still no ID, try finding it inside a data attribute of any child element
    if (commentId.isEmpty) {
      final elementsWithData = commentItem.querySelectorAll('[data-comment]');
      if (elementsWithData.isNotEmpty) {
        commentId = elementsWithData.first.attributes['data-comment'] ?? '';
      }
    }

    // Try additional custom extractors for specific patterns
    if (commentId.isEmpty) {
      // Look for any attribute that might contain comment ID
      final possibleAttributes = ['data-id', 'data-comment-id', 'data-cid'];
      for (final attr in possibleAttributes) {
        if (commentItem.attributes.containsKey(attr)) {
          commentId = commentItem.attributes[attr] ?? '';
          if (commentId.isNotEmpty) break;
        }

        // Also check all child elements
        final children = commentItem.querySelectorAll('*');
        for (final child in children) {
          if (child.attributes.containsKey(attr)) {
            commentId = child.attributes[attr] ?? '';
            if (commentId.isNotEmpty) break;
          }
        }
        if (commentId.isNotEmpty) break;
      }
    }

    // Last resort - create a hash from content and username
    if (commentId.isEmpty) {
      // Extract timestamp and username for generating a unique ID
      final timeElement = commentItem.querySelector('time.timeago');
      final userNameElement =
          commentItem.querySelector('.ln-username') ??
          commentItem.querySelector('.font-bold');

      final userName = userNameElement?.text.trim() ?? '';

      // Try to get a stable timestamp
      final timeString =
          timeElement?.attributes['datetime'] ??
          timeElement?.text.trim() ??
          ''; // Use empty string instead of current time for stability

      // Get a content sample to generate a more reliable ID
      final contentElement =
          commentItem.querySelector('.ln-comment-content') ??
          commentItem.querySelector('.content') ??
          commentItem;

      final contentSample = contentElement.text.trim();

      // Generate a hash only if we have username or content
      if (userName.isNotEmpty || contentSample.isNotEmpty) {
        // Use first part of content for stability
        final contentForHash =
            contentSample.length > 50
                ? contentSample.substring(0, 50)
                : contentSample;

        // Generate a more stable hash from the combination of user + content sample
        final combinedString = '$userName|$contentForHash';
        commentId = 'comment-${combinedString.hashCode}';
      } else {
        // Absolute last resort - use a UUID-like random string with timestamp
        commentId =
            'comment-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(10000)}';
      }
    }

    // Extract user info
    String userImage = '';
    String userName = '';
    String userUrl = '';

    // Try standard avatar container selector
    final avatarContainer = commentItem.querySelector('.w-\\[50px\\]');
    if (avatarContainer != null) {
      final imgElement = avatarContainer.querySelector('img');
      if (imgElement != null) {
        userImage = imgElement.attributes['src'] ?? '';
      }
    }

    // If still no image, try alternative selectors
    if (userImage.isEmpty) {
      // Try looking for avatar images with standard classes
      final imgElements = commentItem.querySelectorAll(
        'img[class*="avatar"], .avatar img, img[src*="avatar"], img.rounded-full',
      );
      if (imgElements.isNotEmpty) {
        userImage = imgElements.first.attributes['src'] ?? '';
      } else {
        // Fallback to first image in the comment
        final allImgs = commentItem.querySelectorAll('img');
        if (allImgs.isNotEmpty) {
          userImage = allImgs.first.attributes['src'] ?? '';
        }
      }
    }

    // Try standard username selector
    userName = commentItem.querySelector('.ln-username')?.text.trim() ?? '';
    userUrl =
        commentItem.querySelector('.ln-username')?.attributes['href'] ?? '';

    // If username is empty, try alternatives
    if (userName.isEmpty) {
      // Try common username selectors
      final usernameElement = commentItem.querySelector(
        '.username, .user-name, .author, [class*="user-name"], .font-bold a, .self-center a.font-bold, a[href*="thanh-vien"]',
      );
      if (usernameElement != null) {
        userName = usernameElement.text.trim();
        if (usernameElement.localName == 'a') {
          userUrl = usernameElement.attributes['href'] ?? '';
        }
      }
    }

    // Get user badges/roles
    final badges = <String>[];

    // Try badge selectors from the HTML structure
    final badgeElements = commentItem.querySelectorAll(
      '.leading-4, .font-bold:not(a), .self-center > div.flex',
    );
    for (final badgeElement in badgeElements) {
      final badgeText = badgeElement.text.trim();
      if (badgeText.isNotEmpty && badgeText != userName) {
        badges.add(badgeText);
      }
    }

    // Extract comment content
    var commentContent =
        commentItem.querySelector('.ln-comment-content')?.text.trim() ?? '';

    // If content is empty, try alternatives
    if (commentContent.isEmpty) {
      // Try common content selectors
      final contentElement = commentItem.querySelector(
        '.content, .comment-content, .text, [class*="content"], .long-text, p',
      );
      if (contentElement != null) {
        commentContent = contentElement.text.trim();

        // If the content includes the username at the beginning, try to remove it
        if (userName.isNotEmpty && commentContent.startsWith(userName)) {
          commentContent = commentContent.substring(userName.length).trim();
        }
      }
    }

    // Extract timestamp
    final timeElement = commentItem.querySelector('time.timeago');
    String timestamp = '';
    String rawTimestamp = '';

    if (timeElement != null) {
      timestamp = timeElement.text.trim();
      rawTimestamp = timeElement.attributes['datetime'] ?? '';
    } else {
      // Try alternative timestamp selectors
      final altTimeElement = commentItem.querySelector(
        '.time, .timestamp, .date, .text-slate-500 a, [class*="time"], [class*="date"], small',
      );
      if (altTimeElement != null) {
        timestamp = altTimeElement.text.trim();
        rawTimestamp = altTimeElement.attributes['datetime'] ?? timestamp;
      }
    }

    // Create comment object
    return {
      'id': commentId,
      'user': {
        'name': userName,
        'image': userImage,
        'url': userUrl,
        'badges': badges,
      },
      'content': commentContent,
      'timestamp': timestamp,
      'rawTimestamp': rawTimestamp,
      'likes': '',
      'replies': <Map<String, dynamic>>[],
    };
  }

  // Helper to extract page number from URL
  int _extractPageNumberFromUrl(String url) {
    final pageMatch = RegExp(r'page=(\d+)').firstMatch(url);
    if (pageMatch != null && pageMatch.group(1) != null) {
      return int.parse(pageMatch.group(1)!);
    }
    return 1; // Default to page 1 if no page number found
  }

  // Helper to construct previous page URL
  String _constructPrevPageUrl(String url, int currentPage) {
    if (currentPage <= 1) return '';

    final baseUrl = url.split('?')[0];
    if (currentPage == 2) {
      // For page 2, going back to page 1 means the original URL without page parameter
      return baseUrl;
    } else {
      // For other pages, decrement the page number
      return '$baseUrl?page=${currentPage - 1}';
    }
  }

  // Add a method to fetch additional replies for a comment
  Future<Map<String, dynamic>> fetchCommentReplies(
    String parentId,
    String offset,
    String afterId,
    BuildContext context,
  ) async {
    try {
      // Get working server
      final server = await _getWorkingServer();
      if (server == null) {
        throw Exception('No server available');
      }

      // Get CSRF token
      String csrfToken = '';
      final tokenResponse = await _httpClient.get(
        '$server',
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );

      if (tokenResponse.statusCode == 200) {
        final htmlDoc = parser.parse(tokenResponse.body);
        final metaTag = htmlDoc.querySelector('meta[name="csrf-token"]');
        csrfToken = metaTag?.attributes['content'] ?? '';
        print('Found CSRF token: ${csrfToken.isNotEmpty ? "Yes" : "No"}');
      }

      // Make the API call to fetch replies
      final response = await _httpClient.post(
        '$server/comment/fetch_reply',
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': server,
          'Referer': '$server',
          'X-CSRF-TOKEN': csrfToken,
        },
        body:
            '_token=${Uri.encodeComponent(csrfToken)}&parent_id=$parentId&offset=$offset&after=$afterId',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load replies: HTTP ${response.statusCode}');
      }

      // Parse the response
      final jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        return {
          'html': jsonResponse['html'],
          'fetchReplyText': jsonResponse['fetchReplyText'],
          'remaining': jsonResponse['remaining'],
        };
      } else {
        throw Exception('Failed to load replies: Invalid response');
      }
    } catch (e) {
      print('Error fetching comment replies: $e');
      CustomToast.show(context, 'Error loading replies: $e');
      return {'html': '', 'fetchReplyText': 'Xem thêm trả lời', 'remaining': 0};
    }
  }
}
