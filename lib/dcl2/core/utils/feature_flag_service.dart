import 'package:injectable/injectable.dart';
import '../../services/preferences_service.dart';
import '../constants/constants.dart';

/// Service to manage feature flags for DCL1 to DCL2 migration
@injectable
class FeatureFlagService {
  final PreferencesService _preferencesService;
  
  FeatureFlagService(this._preferencesService);
  
  /// Check if DCL2 bookmarks feature is enabled
  bool get isDcl2BookmarksEnabled {
    return _preferencesService.getBool(
      'dcl2_bookmarks_enabled',
      defaultValue: Dcl2Constants.enableDcl2Bookmarks,
    );
  }
  
  /// Check if DCL2 settings feature is enabled
  bool get isDcl2SettingsEnabled {
    return _preferencesService.getBool(
      'dcl2_settings_enabled',
      defaultValue: Dcl2Constants.enableDcl2Settings,
    );
  }
  
  /// Check if DCL2 novels feature is enabled
  bool get isDcl2NovelsEnabled {
    return _preferencesService.getBool(
      'dcl2_novels_enabled',
      defaultValue: Dcl2Constants.enableDcl2Novels,
    );
  }
  
  /// Check if DCL2 reader feature is enabled
  bool get isDcl2ReaderEnabled {
    return _preferencesService.getBool(
      'dcl2_reader_enabled',
      defaultValue: Dcl2Constants.enableDcl2Reader,
    );
  }
  
  /// Check if DCL2 auth feature is enabled
  bool get isDcl2AuthEnabled {
    return _preferencesService.getBool(
      'dcl2_auth_enabled',
      defaultValue: Dcl2Constants.enableDcl2Auth,
    );
  }
  
  /// Enable/disable DCL2 bookmarks feature
  Future<void> setDcl2BookmarksEnabled(bool enabled) async {
    await _preferencesService.setBool('dcl2_bookmarks_enabled', enabled);
  }
  
  /// Enable/disable DCL2 settings feature
  Future<void> setDcl2SettingsEnabled(bool enabled) async {
    await _preferencesService.setBool('dcl2_settings_enabled', enabled);
  }
  
  /// Enable/disable DCL2 novels feature
  Future<void> setDcl2NovelsEnabled(bool enabled) async {
    await _preferencesService.setBool('dcl2_novels_enabled', enabled);
  }
  
  /// Enable/disable DCL2 reader feature
  Future<void> setDcl2ReaderEnabled(bool enabled) async {
    await _preferencesService.setBool('dcl2_reader_enabled', enabled);
  }
  
  /// Enable/disable DCL2 auth feature
  Future<void> setDcl2AuthEnabled(bool enabled) async {
    await _preferencesService.setBool('dcl2_auth_enabled', enabled);
  }
  
  /// Get migration status
  String get migrationStatus {
    return _preferencesService.getString(
      Dcl2Constants.dcl2MigrationStatusKey,
      defaultValue: 'not_started',
    );
  }
  
  /// Set migration status
  Future<void> setMigrationStatus(String status) async {
    await _preferencesService.setString(
      Dcl2Constants.dcl2MigrationStatusKey,
      status,
    );
  }
  
  /// Check if any DCL2 feature is enabled
  bool get hasAnyDcl2FeatureEnabled {
    return isDcl2BookmarksEnabled ||
           isDcl2SettingsEnabled ||
           isDcl2NovelsEnabled ||
           isDcl2ReaderEnabled ||
           isDcl2AuthEnabled;
  }
}