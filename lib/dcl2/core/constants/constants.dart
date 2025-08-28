/// Core constants for DCL2 architecture
class Dcl2Constants {
  // Feature flags for gradual migration
  static const bool enableDcl2Bookmarks = false;
  static const bool enableDcl2Settings = false;
  static const bool enableDcl2Novels = false;
  static const bool enableDcl2Reader = false;
  static const bool enableDcl2Auth = false;
  
  // Database constants
  static const String dcl2DatabaseName = 'docln_dcl2.db';
  static const int dcl2DatabaseVersion = 1;
  
  // Cache constants
  static const String dcl2CacheKey = 'dcl2_cache';
  static const Duration defaultCacheDuration = Duration(hours: 1);
  
  // Network constants
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Preferences keys for DCL2
  static const String dcl2MigrationStatusKey = 'dcl2_migration_status';
  static const String dcl2FeatureFlagsKey = 'dcl2_feature_flags';
}