# DCL2 Architecture

DCL2 is the new architecture for the DocLN light novel reader application, designed to replace the legacy DCL1 architecture with a more maintainable, testable, and scalable solution.

## Quick Start

### Prerequisites
- Flutter SDK 3.9.0 or higher
- Dart SDK

### Setup
1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Generate dependency injection code:
   ```bash
   dart pub run build_runner build --delete-conflicting-outputs
   ```

3. Enable DCL2 features (optional):
   ```bash
   ./scripts/dcl2_migration.sh enable bookmarks
   ```

## Architecture Overview

DCL2 follows Clean Architecture principles with feature-based organization:

```
lib/dcl2/
├── core/                    # Shared components
│   ├── constants/           # App constants
│   ├── di/                  # Dependency injection
│   ├── errors/              # Error handling
│   ├── network/             # Network client
│   └── utils/               # Utilities
└── features/                # Feature modules
    └── bookmarks/           # Example feature
        ├── data/            # Data layer
        │   ├── datasources/ # Local/remote data sources
        │   ├── models/      # Data models
        │   └── repositories/# Repository implementations
        ├── domain/          # Business logic
        │   ├── entities/    # Business entities
        │   ├── repositories/# Repository interfaces
        │   └── usecases/    # Use cases
        └── presentation/    # UI layer
            ├── blocs/       # State management (BLoC)
            └── widgets/     # UI components
```

## Key Components

### Dependency Injection
DCL2 uses `get_it` and `injectable` for dependency injection:

```dart
// Register dependencies
@injectable
class BookmarkService {
  // Implementation
}

// Use dependencies
final service = getIt<BookmarkService>();
```

### State Management
DCL2 uses BLoC pattern for state management:

```dart
// Define events
class LoadBookmarks extends BookmarkEvent {}

// Define states
class BookmarkLoaded extends BookmarkState {
  final List<BookmarkEntity> bookmarks;
  const BookmarkLoaded({required this.bookmarks});
}

// Use in UI
BlocBuilder<BookmarkBloc, BookmarkState>(
  builder: (context, state) {
    if (state is BookmarkLoaded) {
      return ListView.builder(/* ... */);
    }
    return CircularProgressIndicator();
  },
)
```

### Feature Flags
DCL2 supports gradual migration through feature flags:

```dart
// Check if DCL2 feature is enabled
if (Dcl2MigrationHelper.shouldUseDcl2Bookmarks()) {
  // Use DCL2 implementation
} else {
  // Use DCL1 implementation
}
```

## Migration Guide

### Phase 1: Enable DCL2 Foundation
1. Initialize DCL2 dependencies in main.dart ✅
2. Set up feature flags ✅

### Phase 2: Migrate Features
1. Enable bookmarks feature:
   ```bash
   ./scripts/dcl2_migration.sh enable bookmarks
   ```

2. Test the feature works correctly

3. Gradually enable other features

### Phase 3: Complete Migration
1. Update all UI components to use DCL2
2. Remove DCL1 legacy code
3. Final testing and optimization

## Development Tools

### Migration Script
Use the migration script for common tasks:

```bash
# Show current status
./scripts/dcl2_migration.sh status

# Enable a feature
./scripts/dcl2_migration.sh enable bookmarks

# Generate dependency injection code
./scripts/dcl2_migration.sh generate
```

### Feature Flags
Control DCL2 features through constants or at runtime:

```dart
// In constants.dart
static const bool enableDcl2Bookmarks = true;

// Or programmatically
await Dcl2MigrationHelper.enableDcl2Feature('bookmarks');
```

## Testing

### Unit Tests
Test individual components:

```dart
test('should return bookmarks when repository call is successful', () async {
  // Arrange
  final mockRepository = MockBookmarkRepository();
  final useCase = GetBookmarks(mockRepository);
  
  // Act
  final result = await useCase(NoParams());
  
  // Assert
  expect(result.isRight(), true);
});
```

### Integration Tests
Test feature interactions:

```dart
testWidgets('should display bookmarks when loaded', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());
  
  // Act
  await tester.tap(find.byKey(Key('bookmarks_tab')));
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.byType(BookmarkList), findsOneWidget);
});
```

## Best Practices

### Code Organization
- Keep features independent
- Use clear naming conventions
- Separate concerns by layer

### Error Handling
- Use Either type for error handling
- Define specific failure types
- Handle errors gracefully in UI

### Performance
- Use BLoC for efficient state management
- Implement proper caching strategies
- Optimize network calls

## Contributing

1. Follow Clean Architecture principles
2. Write tests for new features
3. Use dependency injection
4. Update documentation

## Troubleshooting

### Common Issues

**Dependency injection not working:**
```bash
dart pub run build_runner build --delete-conflicting-outputs
```

**Feature flags not working:**
- Check if DCL2 is properly initialized
- Verify feature flag constants
- Ensure preferences service is working

**BLoC state not updating:**
- Check if BLoC is properly provided
- Verify events are being dispatched
- Check for state equality issues

For more detailed information, see [MIGRATION_GUIDE.md](../MIGRATION_GUIDE.md).