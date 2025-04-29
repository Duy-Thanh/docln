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
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
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

  // Fix image URLs based on DNS settings
  String fixImageUrl(String url) {
    // Handle common image domains that might be blocked
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return url; // Return original if parsing fails
    }

    // Map of problematic image domains and their alternatives
    const Map<String, List<String>> imageDomainFallbacks = {
      'i.docln.net': ['i.hako.vip', 'i2.hako.vip', 'i.ln.hako.vn'],
      'i2.docln.net': ['i2.hako.vip', 'i.hako.vip', 'i2.ln.hako.vn'],
      'i3.docln.net': ['i3.hako.vip', 'i.hako.vip', 'i3.ln.hako.vn'],
    };

    // Check if the host is in our problematic domains list
    if (imageDomainFallbacks.containsKey(uri.host)) {
      // Replace with first fallback domain
      final newHost = imageDomainFallbacks[uri.host]!.first;
      print('Fixing image URL: ${uri.host} -> $newHost');
      return url.replaceFirst(uri.host, newHost);
    }

    return url;
  }

  // Add DNS-aware image loading method
  Future<String> getOptimizedImageUrl(String originalUrl) async {
    if (!_isDnsEnabled) {
      return fixImageUrl(
        originalUrl,
      ); // Just use the basic fix if DNS not enabled
    }

    try {
      // Try to connect to the original URL first
      final originalUri = Uri.parse(originalUrl);

      // Prepare a list of potential URL variations
      List<String> urlVariations = [originalUrl];

      // Add fixes for common problematic domains
      const Map<String, List<String>> imageDomainFallbacks = {
        'i.docln.net': ['i.hako.vip', 'i2.hako.vip', 'i.ln.hako.vn'],
        'i2.docln.net': ['i2.hako.vip', 'i.hako.vip', 'i2.ln.hako.vn'],
        'i3.docln.net': ['i3.hako.vip', 'i.hako.vip', 'i3.ln.hako.vn'],
      };

      // If the domain is in our problem list, add alternatives
      if (imageDomainFallbacks.containsKey(originalUri.host)) {
        for (final alternativeHost in imageDomainFallbacks[originalUri.host]!) {
          final alternativeUrl = originalUrl.replaceFirst(
            originalUri.host,
            alternativeHost,
          );
          urlVariations.add(alternativeUrl);
        }
      }

      // Try each URL variation until one works
      for (final url in urlVariations) {
        try {
          // Just check if the URL is accessible
          final response = await _httpClient.get(
            url,
            headers: {
              'Accept': 'image/*',
              'Range': 'bytes=0-1024',
            }, // Just get the header
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            return url; // This URL works
          }
        } catch (e) {
          // Just continue to the next variation
          continue;
        }
      }

      // If all variations failed, return the original
      return originalUrl;
    } catch (e) {
      print('Error optimizing image URL: $e');
      return originalUrl; // Return original URL as fallback
    }
  }

  // Override the extract cover URL method to use DNS awareness
  String _extractCoverUrl(dom.Element? coverElement) {
    if (coverElement == null) {
      return 'https://ln.hako.vn/img/nocover.jpg';
    }

    // Try to get from data-bg attribute
    String? dataBg = coverElement.attributes['data-bg'];
    if (dataBg != null && dataBg.isNotEmpty) {
      return fixImageUrl(dataBg);
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
        return fixImageUrl(url);
      }
    }

    // If all else fails, return default image
    return 'https://ln.hako.vn/img/nocover.jpg';
  }

  // Add a new method to fetch chapter content
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
          'Failed to load chapter content: HTTP ${response.statusCode}',
        );
      }

      final document = parser.parse(response.body);

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
        // Remove any script or ad elements
        contentElement
            .querySelectorAll('script, .ads, [id*="ads"], [class*="ads"]')
            .forEach((e) => e.remove());

        // Clean and format the content
        content = _cleanContent(contentElement.innerHtml);
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
    } catch (e) {
      print('Error fetching chapter content: $e');
      CustomToast.show(context, 'Error loading chapter: $e');
      return {
        'title': 'Error',
        'content':
            '<p>Failed to load chapter content. Please try again later.</p><p>Error: $e</p>',
      };
    }
  }

  // Helper method to clean HTML content
  String _cleanContent(String html) {
    // Remove excessive whitespace and newlines
    html = html.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Convert div and span elements to paragraphs for better reading
    html = html.replaceAll(
      RegExp(r'<div[^>]*>(.*?)</div>', dotAll: true),
      '<p>\$1</p>',
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

    return html;
  }
}
