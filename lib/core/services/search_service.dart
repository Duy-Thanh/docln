import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'dart:convert';
import 'package:docln/core/models/search_result.dart';
import 'settings_services.dart';

class SearchService {
  // Default base URL - will be overridden by user's selected server
  static const String defaultBaseUrl = "https://docln.sbs";

  // Get the current server from settings
  Future<String> _getBaseUrl() async {
    final settingsService = SettingsService();
    return await settingsService.getCurrentServer() ?? defaultBaseUrl;
  }

  // Image domains mapping for fallback
  static const Map<String, List<String>> imageDomainFallbacks = {
    'i.docln.net': ['i.hako.vip', 'i2.hako.vip'],
    'i2.docln.net': ['i2.hako.vip', 'i.hako.vip'],
  };

  // Fix image URL if it's using a problematic domain
  static String fixImageUrl(String url) {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return url; // Return original if parsing fails
    }

    // Check if the host is in our problematic domains list
    if (imageDomainFallbacks.containsKey(uri.host)) {
      // Replace with first fallback domain
      final newHost = imageDomainFallbacks[uri.host]!.first;
      return url.replaceFirst(uri.host, newHost);
    }

    return url;
  }

  Future<SearchResponse> search(String keyword, {int page = 1}) async {
    try {
      // Get the base URL from user settings
      final baseUrl = await _getBaseUrl();

      // Encode the keyword for URL - use it for both query and keywords parameters
      final encodedKeyword = Uri.encodeComponent(keyword);
      final url =
          "$baseUrl/tim-kiem?query=$encodedKeyword&keywords=$encodedKeyword&page=$page";

      // Make the HTTP request
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to search: ${response.statusCode}');
      }

      // Parse the HTML content
      final document = parser.parse(utf8.decode(response.bodyBytes));

      // Check if there are no results
      final noResultsElement = document.querySelector('.listext-item.clear');
      if (noResultsElement != null &&
          noResultsElement.text.contains("Không có truyện nào")) {
        return SearchResponse(
          results: [],
          hasResults: false,
          currentPage: page,
          totalPages: 1,
        );
      }

      // Extract search results
      final resultItems = document.querySelectorAll('.thumb-item-flow');
      final results = <SearchResult>[];

      for (var item in resultItems) {
        // Check if this is an original work
        final isOriginal = item.classes.contains('type-original');

        // Extract cover URL
        final coverElement = item.querySelector('.img-in-ratio');
        String coverUrl = 'https://ln.hako.vn/img/nocover.jpg'; // Default
        if (coverElement != null) {
          final dataBg = coverElement.attributes['data-bg'];
          if (dataBg != null && dataBg.isNotEmpty) {
            coverUrl = fixImageUrl(dataBg); // Apply domain fix
          }
        }

        // Extract chapter information
        final chapterElement = item.querySelector(
          '.thumb_attr.chapter-title a',
        );
        final chapterTitle = chapterElement?.text ?? '';
        final chapterUrl = chapterElement?.attributes['href'] ?? '';

        // Extract volume information
        final volumeElement = item.querySelector('.thumb_attr.volume-title');
        final volumeTitle = volumeElement?.text ?? '';

        // Extract series information
        final seriesElement = item.querySelector('.thumb_attr.series-title a');
        final seriesTitle = seriesElement?.text ?? '';
        final seriesUrl = seriesElement?.attributes['href'] ?? '';

        // Create the SearchResult object
        results.add(
          SearchResult(
            title: chapterTitle,
            url: chapterUrl.isNotEmpty ? baseUrl + chapterUrl : '',
            coverUrl: coverUrl,
            chapterTitle: chapterTitle,
            chapterUrl: chapterUrl.isNotEmpty ? baseUrl + chapterUrl : '',
            volumeTitle: volumeTitle,
            isOriginal: isOriginal,
            seriesTitle: seriesTitle,
            seriesUrl: seriesUrl.isNotEmpty ? baseUrl + seriesUrl : '',
          ),
        );
      }

      // Get pagination information
      int totalPages = 1;
      int currentPage = page;

      // Extract current page from pagination
      final currentPageElement = document.querySelector(
        '.paging_item.page_num.current',
      );
      if (currentPageElement != null) {
        final currentPageText = currentPageElement.text.trim();
        currentPage = int.tryParse(currentPageText) ?? page;
      }

      // Get total pages from pagination
      final paginationElements = document.querySelectorAll(
        '.paging_item.page_num',
      );
      if (paginationElements.isNotEmpty) {
        // Try to get last page from the "Cuối" link
        final lastPageLink = document.querySelector(
          '.paging_item.paging_prevnext.next',
        );
        if (lastPageLink != null) {
          final lastPageHref = lastPageLink.attributes['href'];
          if (lastPageHref != null) {
            try {
              final uri = Uri.parse(lastPageHref);
              final pageParam = uri.queryParameters['page'];
              if (pageParam != null) {
                totalPages = int.tryParse(pageParam) ?? 1;
              }
            } catch (e) {
              // In case of parsing error, fallback to counting page elements
              totalPages = paginationElements.length;
            }
          }
        } else {
          // If there's no "last page" link, count the number of page links
          totalPages = paginationElements.length;
        }
      }

      return SearchResponse(
        results: results,
        hasResults: results.isNotEmpty,
        currentPage: currentPage,
        totalPages: totalPages,
        keyword: keyword,
      );
    } catch (e) {
      throw Exception('Error during search: $e');
    }
  }
}
