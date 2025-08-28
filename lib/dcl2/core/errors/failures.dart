import 'package:equatable/equatable.dart';

/// Base class for DCL2 failures
abstract class Failure extends Equatable {
  final String message;
  final int? code;
  
  const Failure({required this.message, this.code});
  
  @override
  List<Object?> get props => [message, code];
}

/// Network related failures
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

/// Cache related failures
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// Database related failures
class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code});
}

/// Server related failures
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Validation related failures
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// Generic failure for unexpected errors
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.code});
}