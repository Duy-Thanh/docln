import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hako_models.dart';

class ApiService {
  // ĐỔI CÁI NÀY NẾU CHẠY MÁY THẬT (VD: http://192.168.1.5:3500)
  static const String baseUrl = "http://10.0.2.2:3500/api";

  // 1. LẤY TRANG CHỦ (LEVEL 1)
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

  // 2. LẤY CHI TIẾT TRUYỆN (LEVEL 2)
  Future<NovelDetail> fetchNovelDetail(String url) async {
    try {
      // Gửi URL truyện lên server để nó cào
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

  // 3. LẤY NỘI DUNG CHƯƠNG (LEVEL 3)
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
}
