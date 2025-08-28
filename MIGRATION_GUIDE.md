# DCL1 to DCL2 Architecture Migration Guide

## Overview

This document outlines the migration strategy from the legacy DCL1 architecture to the new DCL2 architecture for the DocLN light novel reader application. The migration is designed to be gradual and non-breaking, allowing for smooth transition while maintaining application stability.

## Architecture Comparison

### DCL1 Architecture (Legacy)
- **Pattern**: Provider pattern for state management
- **Structure**: Layer-based organization (screens, services, modules, widgets)
- **Dependency Management**: Singleton pattern with manual initialization
- **Service Coupling**: Tight coupling between services
- **Data Management**: Mixed responsibilities in services

### DCL2 Architecture (New)
- **Pattern**: Clean Architecture with BLoC pattern
- **Structure**: Feature-based organization with layered separation
- **Dependency Management**: Dependency injection with get_it/injectable
- **Service Coupling**: Loose coupling with clear interfaces
- **Data Management**: Clear separation of data, domain, and presentation layers

## Migration Strategy

### Phase 1: Foundation Setup ✅
- [x] Create DCL2 directory structure
- [x] Set up dependency injection framework
- [x] Create base classes and interfaces
- [x] Add feature flag system

### Phase 2: Core Infrastructure ✅
- [x] Repository pattern interfaces
- [x] Use cases and entities
- [x] BLoC/Cubit foundation
- [x] Error handling framework

### Phase 3: Feature Migration (Current)
#### Bookmarks Feature ✅
- [x] Domain layer implementation
- [x] Data layer with local storage
- [x] Presentation layer with BLoC
- [x] Migration helper for DCL1 data

#### Settings Feature (Next)
- [ ] Migrate preferences management
- [ ] Create settings use cases
- [ ] Implement settings BLoC

#### Other Features (Planned)
- [ ] Novel browsing
- [ ] Reader functionality
- [ ] Authentication

### Phase 4: UI Layer Migration
- [ ] Replace Provider with BLoC
- [ ] Update screens to use new architecture
- [ ] Migrate navigation

### Phase 5: Cleanup
- [ ] Remove DCL1 legacy code
- [ ] Performance optimizations
- [ ] Final testing

## Feature Flags

The migration uses feature flags to gradually enable DCL2 features:

```dart
// Check if DCL2 bookmarks should be used
if (Dcl2MigrationHelper.shouldUseDcl2Bookmarks()) {
  // Use DCL2 bookmark BLoC
} else {
  // Use DCL1 bookmark service
}
```

### Available Feature Flags
- `dcl2_bookmarks_enabled`: Enable DCL2 bookmarks feature
- `dcl2_settings_enabled`: Enable DCL2 settings feature
- `dcl2_novels_enabled`: Enable DCL2 novel browsing feature
- `dcl2_reader_enabled`: Enable DCL2 reader feature
- `dcl2_auth_enabled`: Enable DCL2 authentication feature

## Enabling DCL2 Features

### Programmatically
```dart
// Enable DCL2 bookmarks
await Dcl2MigrationHelper.enableDcl2Feature('bookmarks');

// Enable DCL2 settings
await Dcl2MigrationHelper.enableDcl2Feature('settings');
```

### Via Constants (Development)
```dart
// In lib/dcl2/core/constants/constants.dart
class Dcl2Constants {
  static const bool enableDcl2Bookmarks = true; // Change to true
  static const bool enableDcl2Settings = false;
  // ...
}
```

## Data Migration

### Bookmarks Migration
The bookmark migration automatically transfers data from DCL1 format to DCL2:

```dart
// DCL1 format (LightNovel objects in JSON)
{
  "id": "novel_123",
  "title": "Novel Title",
  "coverUrl": "https://...",
  "author": "Author Name",
  "latestChapter": "Chapter 5"
}

// DCL2 format (BookmarkEntity)
{
  "id": "bookmark_1",
  "novelId": "novel_123",
  "title": "Novel Title",
  "coverUrl": "https://...",
  "author": "Author Name",
  "latestChapter": "Chapter 5",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## Testing DCL2 Features

### Unit Testing
Each DCL2 component can be tested independently:

```dart
// Example: Testing bookmark use case
test('should add bookmark successfully', () async {
  // Arrange
  final repository = MockBookmarkRepository();
  final useCase = AddBookmark(repository);
  final bookmark = BookmarkEntity(...);
  
  // Act
  final result = await useCase(AddBookmarkParams(bookmark: bookmark));
  
  // Assert
  expect(result.isRight(), true);
});
```

### Integration Testing
Feature flags allow testing DCL2 features alongside DCL1:

```dart
// Enable DCL2 for specific tests
await Dcl2MigrationHelper.enableDcl2Feature('bookmarks');
// Run tests
// Disable after tests
await Dcl2MigrationHelper.enableDcl2Feature('bookmarks', false);
```

## Rollback Strategy

If issues are encountered, DCL2 features can be disabled immediately:

```dart
// Disable DCL2 bookmarks and fall back to DCL1
await featureFlagService.setDcl2BookmarksEnabled(false);
```

The application will automatically fall back to DCL1 implementation.

## Benefits of DCL2

### For Developers
- **Better testability**: Each layer can be tested independently
- **Cleaner code**: Clear separation of concerns
- **Easier maintenance**: Modular, feature-based organization
- **Type safety**: Strong typing with Dart's type system

### For Users
- **Better performance**: More efficient state management
- **Improved stability**: Better error handling and recovery
- **Enhanced features**: New capabilities enabled by cleaner architecture

## Next Steps

1. **Enable bookmarks migration**: Set `enableDcl2Bookmarks = true` in constants
2. **Test bookmark functionality**: Verify migration and new features work correctly
3. **Implement settings migration**: Next feature to migrate
4. **Monitor performance**: Ensure DCL2 features perform well
5. **Gather feedback**: Collect user and developer feedback

## Migration Timeline

- **Phase 1-2**: ✅ Completed (Foundation and infrastructure)
- **Phase 3a**: ✅ Completed (Bookmarks feature)
- **Phase 3b**: 📋 In Progress (Settings feature)
- **Phase 3c-e**: 📅 Planned (Other features)
- **Phase 4**: 📅 Q2 2024 (UI migration)
- **Phase 5**: 📅 Q3 2024 (Cleanup)

## Support

For questions or issues during migration:
1. Check feature flag status
2. Review error logs for DCL2 components
3. Use rollback strategy if needed
4. Report issues with detailed reproduction steps