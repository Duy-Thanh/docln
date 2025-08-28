import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../models/chapter_model.dart';

abstract class ChapterRemoteDataSource {
  Future<List<ChapterModel>> getChapters(String novelId);
  Future<ChapterModel> getChapter(String id);
  Future<String> getChapterContent(String id);
}

@Injectable(as: ChapterRemoteDataSource)
class ChapterRemoteDataSourceImpl implements ChapterRemoteDataSource {
  final ApiClient _apiClient;

  ChapterRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<ChapterModel>> getChapters(String novelId) async {
    try {
      final response = await _apiClient.dio.get('/api/novels/$novelId/chapters');
      final data = response.data as List;
      return data.map((json) => ChapterModel.fromJson(json)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch chapters: ${e.toString()}');
    }
  }

  @override
  Future<ChapterModel> getChapter(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/chapters/$id');
      return ChapterModel.fromJson(response.data);
    } catch (e) {
      throw ServerException('Failed to fetch chapter: ${e.toString()}');
    }
  }

  @override
  Future<String> getChapterContent(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/chapters/$id/content');
      return response.data['content'] as String;
    } catch (e) {
      throw ServerException('Failed to fetch chapter content: ${e.toString()}');
    }
  }
}
