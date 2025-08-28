import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../constants/constants.dart';
import '../errors/exceptions.dart';

/// Network client for DCL2 architecture
@injectable
class Dcl2NetworkClient {
  late final Dio _dio;
  
  Dcl2NetworkClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: Dcl2Constants.defaultTimeout,
      receiveTimeout: Dcl2Constants.defaultTimeout,
      sendTimeout: Dcl2Constants.defaultTimeout,
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
    
    // Retry interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 500 || 
            error.type == DioExceptionType.connectionTimeout) {
          // Implement retry logic here if needed
        }
        handler.next(error);
      },
    ));
  }
  
  /// GET request
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  /// POST request  
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  /// PUT request
  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  /// DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  Exception _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(message: 'Connection timeout');
      case DioExceptionType.badResponse:
        return ServerException(
          message: 'Server error: ${e.response?.statusCode}',
          code: e.response?.statusCode,
        );
      case DioExceptionType.cancel:
        return const NetworkException(message: 'Request was cancelled');
      default:
        return NetworkException(message: 'Network error: ${e.message}');
    }
  }
}