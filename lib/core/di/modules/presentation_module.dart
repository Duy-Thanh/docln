import 'package:injectable/injectable.dart';

@module
abstract class PresentationModule {
  // Presentation module is mainly for registering BLoCs and other UI-related services
  // The actual implementations will be registered in the feature modules
}
