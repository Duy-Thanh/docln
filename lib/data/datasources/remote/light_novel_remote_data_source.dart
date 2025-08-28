import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../models/light_novel_model.dart';

abstract class LightNovelRemoteDataSource {
  Future<List<LightNovelModel>> getLightNovels({
    required int page,
    required int limit,
  });

  Future<LightNovelModel> getLightNovel(String id);
}

@Injectable(as: LightNovelRemoteDataSource)
class LightNovelRemoteDataSourceImpl implements LightNovelRemoteDataSource {
  final ApiClient _apiClient;

  LightNovelRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<LightNovelModel>> getLightNovels({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/light-novels',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data as List;
      return data.map((json) => LightNovelModel.fromJson(json)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch light novels: ${e.toString()}');
    }
  }

  @override
  Future<LightNovelModel> getLightNovel(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/light-novels/$id');
      return LightNovelModel.fromJson(response.data);
    } catch (e) {
      throw ServerException('Failed to fetch light novel: ${e.toString()}');
    }
  }
}
