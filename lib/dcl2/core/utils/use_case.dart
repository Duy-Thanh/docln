import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base use case for DCL2 architecture
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// No parameters use case
class NoParams {
  const NoParams();
}

/// Base parameters class
abstract class Params {
  const Params();
}