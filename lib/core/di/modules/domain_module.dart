import 'package:injectable/injectable.dart';

@module
abstract class DomainModule {
  // Domain module is mainly for registering use cases and repositories
  // The actual implementations will be registered in the data module
}
