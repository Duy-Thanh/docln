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
import 'dart:async';

class CrawlerService {
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
    // Try primary servers first
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
    const int chunkSize = 50000; // 50KB chunks
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
}
