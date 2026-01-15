import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hako_models.dart';

// Import model cũ để mapping (đỡ phải sửa UI)
import '../models/search_result.dart';
import '../modules/comment.dart';
// Nếu Comment model nằm ở file khác thì sửa lại import nhé

class ApiService {
  // Thay đổi IP này nếu chạy trên thiết bị thật
  static const String baseUrl = "http://10.0.2.2:3500/api";

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 1. LẤY TRANG CHỦ
  Future<Map<String, List<NovelBasic>>> fetchHome() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/home'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        return {
          'featured': (data['featured'] as List)
              .map((e) => NovelBasic.fromJson(e))
              .toList(),
          'original': (data['original'] as List)
              .map((e) => NovelBasic.fromJson(e))
              .toList(),
          'translation': (data['translation'] as List)
              .map((e) => NovelBasic.fromJson(e))
              .toList(),
          'newSeries': (data['newSeries'] as List)
              .map((e) => NovelBasic.fromJson(e))
              .toList(),
        };
      } else {
        throw Exception('Failed to load home: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching home: $e");
      rethrow;
    }
  }

  // 2. LẤY CHI TIẾT TRUYỆN
  Future<NovelDetail> fetchNovelDetail(String url) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/novel?url=$url'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          return NovelDetail.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['error']);
        }
      } else {
        throw Exception('Failed to load novel: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching novel: $e");
      rethrow;
    }
  }

  // 3. LẤY NỘI DUNG CHƯƠNG
  Future<List<ChapterContent>> fetchChapterContent(String url) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chapter?url=$url'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          return (jsonResponse['data'] as List)
              .map((e) => ChapterContent.fromJson(e))
              .toList();
        } else {
          throw Exception(jsonResponse['error']);
        }
      } else {
        throw Exception('Failed to load chapter: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching chapter: $e");
      rethrow;
    }
  }

  // 4. TÌM KIẾM (NEW)
  Future<SearchResponse> search(String keyword, {int page = 1}) async {
    try {
      // Backend của mày hiện tại chưa hỗ trợ page ở API search, nó trả về list full
      // Tao cứ truyền param keyword lên thôi
      final response = await http.get(
        Uri.parse('$baseUrl/search?keyword=$keyword'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> resultsJson = jsonResponse['data'];

          // Map từ API response sang SearchResult model cũ
          final List<SearchResult> results = resultsJson.map((item) {
            return SearchResult(
              id: item['id']?.toString() ?? '', // API trả về id
              title:
                  item['title'] ??
                  '', // Title của kết quả (thường trùng seriesTitle)
              url:
                  item['url'] ?? '', // URL của kết quả (thường trùng seriesUrl)
              coverUrl: item['cover'] ?? '',
              seriesTitle: item['title'] ?? '',
              chapterTitle: item['latestChapter'] ?? '',
              seriesUrl: item['url'] ?? '',
              chapterUrl:
                  '', // API search hiện tại chưa trả về link chương mới nhất cụ thể, kệ nó
              volumeTitle: '',
              isOriginal: false, // API chưa check, tạm để false
            );
          }).toList();

          // Fake pagination vì backend mày chưa làm phân trang
          return SearchResponse(
            keyword: keyword,
            results: results,
            currentPage: 1,
            totalPages: 1,
            hasResults: results.isNotEmpty,
          );
        } else {
          throw Exception(jsonResponse['error']);
        }
      } else {
        throw Exception('Failed to search: ${response.statusCode}');
      }
    } catch (e) {
      print("Error searching: $e");
      rethrow;
    }
  }

  // 5. BÌNH LUẬN (NEW)
  Future<List<Comment>> getComments(String url) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/comments?url=$url'));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> list = jsonResponse['data'];

          // Map từ API response (phẳng) sang Comment model (cấu trúc cũ)
          return list.map((item) {
            // Tạo cấu trúc JSON giả lập giống cái Crawler cũ trả về để Comment.fromJson parse được
            final Map<String, dynamic> compatJson = {
              'id': DateTime.now().millisecondsSinceEpoch.toString(), // Fake ID
              'content': item['content'],
              'timestamp': item['time'],
              'user': {
                'name': item['username'],
                'image': item['avatar'] ?? '',
                'url': '',
                'badges': [],
              },
              'replies': [], // API mày chưa làm reply
              'parentId': null,
            };
            return Comment.fromJson(compatJson);
          }).toList();
        } else {
          throw Exception(jsonResponse['error']);
        }
      } else {
        throw Exception('Failed to load comments: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching comments: $e");
      rethrow;
    }
  }
}
