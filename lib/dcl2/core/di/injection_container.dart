import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection_container.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() => getIt.init();

/// Initialize DCL2 dependency injection
/// This will be called alongside DCL1 initialization during migration
Future<void> initializeDcl2Dependencies() async {
  try {
    await configureDependencies();
    print('DCL2 dependency injection initialized successfully');
  } catch (e) {
    print('Failed to initialize DCL2 dependency injection: $e');
    // Don't throw to avoid breaking DCL1 functionality
  }
}

/// Check if DCL2 is available
bool isDcl2Available() {
  try {
    return getIt.isRegistered();
  } catch (e) {
    return false;
  }
}