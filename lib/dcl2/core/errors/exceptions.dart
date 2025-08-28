/// Custom exceptions for DCL2 architecture
class ServerException implements Exception {
  final String message;
  final int? code;
  
  const ServerException({required this.message, this.code});
}

class NetworkException implements Exception {
  final String message;
  final int? code;
  
  const NetworkException({required this.message, this.code});
}

class CacheException implements Exception {
  final String message;
  final int? code;
  
  const CacheException({required this.message, this.code});
}

class DatabaseException implements Exception {
  final String message;
  final int? code;
  
  const DatabaseException({required this.message, this.code});
}

class ValidationException implements Exception {
  final String message;
  final int? code;
  
  const ValidationException({required this.message, this.code});
}