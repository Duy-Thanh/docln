import 'package:injectable/injectable.dart';
import '../../../services/preferences_service.dart';

/// Registration module for DCL2 dependencies
@module
abstract class RegisterModule {
  /// Register PreferencesService from DCL1 for use in DCL2
  @injectable
  PreferencesService get preferencesService => PreferencesService();
}