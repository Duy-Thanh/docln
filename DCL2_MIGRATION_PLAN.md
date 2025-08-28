# DCL1 to DCL2 Migration Plan

## Current DCL1 Architecture Analysis

### Key Characteristics of DCL1:
- **State Management**: Provider pattern with multiple singleton services
- **Data Layer**: Mixed (Supabase + SQLite + SharedPreferences)
- **Architecture**: No clear architectural pattern
- **Dependencies**: Heavy reliance on web scraping from Hako website
- **Services**: Large monolithic service classes (2000+ lines)
- **UI**: Traditional Flutter screens with direct service calls

### Identified Issues:
1. **Tight Coupling**: Services directly coupled to UI through Provider
2. **Data Inconsistency**: Multiple data sources with complex migration logic
3. **Scalability**: Large service classes difficult to maintain
4. **Testability**: Hard to unit test due to tight coupling
5. **Web Scraping Risk**: Dependent on external website structure changes
6. **State Management**: Scattered state logic across services

## Proposed DCL2 Architecture

### Clean Architecture Approach:
```
lib/
├── core/                    # Core functionality
│   ├── di/                 # Dependency Injection
│   ├── error/              # Error handling
│   ├── network/            # Network configuration
│   └── usecases/           # Application use cases
├── data/                   # Data layer
│   ├── datasources/        # Data sources (API, DB, Cache)
│   ├── models/             # Data models (API responses)
│   └── repositories/       # Repository implementations
├── domain/                 # Domain layer
│   ├── entities/           # Business entities
│   ├── repositories/       # Repository contracts
│   └── usecases/           # Use cases
├── presentation/           # Presentation layer
│   ├── blocs/              # BLoC state management
│   ├── pages/              # Screen pages
│   ├── widgets/            # UI components
│   └── themes/             # App themes
└── features/               # Feature modules
    ├── auth/
    ├── library/
    ├── reader/
    └── search/
```

### Key Improvements:
1. **Clean Separation**: Clear separation of concerns
2. **Testability**: Easy to unit test each layer
3. **Maintainability**: Modular, feature-based structure
4. **Scalability**: Easy to add new features
5. **State Management**: BLoC pattern for predictable state
6. **Dependency Injection**: Clean DI with injectable
7. **Error Handling**: Centralized error handling
8. **Data Flow**: Unidirectional data flow

## Migration Strategy

### Phase 1: Foundation (Week 1-2)
**Goal**: Set up new architecture foundation without breaking DCL1

1. **Create New Structure**:
   - Set up directory structure
   - Create core abstractions
   - Set up dependency injection

2. **Data Layer Migration**:
   - Create repository contracts
   - Implement data sources
   - Create domain entities

3. **State Management Setup**:
   - Set up BLoC architecture
   - Create base BLoC classes

### Phase 2: Feature Migration (Week 3-6)
**Goal**: Migrate features one by one

1. **Authentication**:
   - Migrate AuthService to new architecture
   - Create auth BLoC
   - Update UI to use new auth flow

2. **Library Management**:
   - Migrate library-related services
   - Create library BLoC
   - Update library screens

3. **Reader**:
   - Migrate reader functionality
   - Create reader BLoC
   - Update reader screens

### Phase 3: Integration & Testing (Week 7-8)
**Goal**: Integrate all features and ensure stability

1. **Service Integration**:
   - Migrate remaining services
   - Update all screens
   - Test integration

2. **Data Migration**:
   - Ensure data compatibility
   - Test data migration
   - Validate user data integrity

### Phase 4: Optimization & Launch (Week 9-10)
**Goal**: Performance optimization and final testing

1. **Performance**:
   - Optimize BLoC state management
   - Improve data caching
   - Memory leak fixes

2. **Testing**:
   - Unit tests for all layers
   - Integration tests
   - UI tests

## Implementation Details

### 1. Dependency Injection Setup
```yaml
# pubspec.yaml additions
dependencies:
  flutter_bloc: ^8.1.3
  bloc: ^8.1.2
  injectable: ^2.4.1
  get_it: ^7.6.7
  dio: ^5.4.0
  hive: ^2.2.3
  path_provider: ^2.1.3
```

### 2. Core Architecture Components

#### Domain Layer:
```dart
// domain/entities/light_novel.dart
class LightNovelEntity {
  final String id;
  final String title;
  final String coverUrl;
  final String url;
  // ... other properties

  const LightNovelEntity({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
  });
}

// domain/repositories/light_novel_repository.dart
abstract class LightNovelRepository {
  Future<List<LightNovelEntity>> getLightNovels();
  Future<LightNovelEntity?> getLightNovel(String id);
  Future<void> saveLightNovel(LightNovelEntity novel);
}
```

#### Data Layer:
```dart
// data/models/light_novel_model.dart
class LightNovelModel extends LightNovelEntity {
  const LightNovelModel({
    required super.id,
    required super.title,
    required super.coverUrl,
    required super.url,
  });

  factory LightNovelModel.fromJson(Map<String, dynamic> json) {
    return LightNovelModel(
      id: json['id'],
      title: json['title'],
      coverUrl: json['coverUrl'],
      url: json['url'],
    );
  }
}

// data/datasources/light_novel_remote_data_source.dart
class LightNovelRemoteDataSource {
  final Dio _dio;

  LightNovelRemoteDataSource(this._dio);

  Future<List<LightNovelModel>> getLightNovels() async {
    final response = await _dio.get('/light-novels');
    return (response.data as List)
        .map((json) => LightNovelModel.fromJson(json))
        .toList();
  }
}
```

#### Presentation Layer:
```dart
// presentation/blocs/light_novel/light_novel_bloc.dart
class LightNovelBloc extends Bloc<LightNovelEvent, LightNovelState> {
  final GetLightNovelsUseCase _getLightNovelsUseCase;

  LightNovelBloc(this._getLightNovelsUseCase)
      : super(LightNovelInitial()) {
    on<LoadLightNovels>(_onLoadLightNovels);
  }

  Future<void> _onLoadLightNovels(
    LoadLightNovels event,
    Emitter<LightNovelState> emit,
  ) async {
    emit(LightNovelLoading());
    try {
      final novels = await _getLightNovelsUseCase();
      emit(LightNovelLoaded(novels));
    } catch (e) {
      emit(LightNovelError(e.toString()));
    }
  }
}
```

### 3. Migration Checklist

#### ✅ Phase 1 Checklist:
- [ ] Create new directory structure
- [ ] Set up dependency injection
- [ ] Create domain entities
- [ ] Create repository contracts
- [ ] Set up BLoC base classes
- [ ] Create data sources
- [ ] Set up error handling

#### ✅ Phase 2 Checklist:
- [ ] Migrate authentication feature
- [ ] Migrate library feature
- [ ] Migrate reader feature
- [ ] Migrate search feature
- [ ] Update all screens to use BLoC
- [ ] Test each feature independently

#### ✅ Phase 3 Checklist:
- [ ] Integrate all features
- [ ] Test data migration
- [ ] Validate user data integrity
- [ ] Performance testing
- [ ] Memory leak testing

#### ✅ Phase 4 Checklist:
- [ ] Final integration testing
- [ ] User acceptance testing
- [ ] Performance optimization
- [ ] Documentation update
- [ ] Deployment preparation

## Risk Mitigation

### 1. Data Migration Risks:
- **Risk**: Data loss during migration
- **Mitigation**: Comprehensive backup/restore system
- **Testing**: Thorough testing of migration scripts

### 2. Breaking Changes:
- **Risk**: Breaking existing functionality
- **Mitigation**: Feature flags for gradual rollout
- **Testing**: Extensive integration testing

### 3. Performance Impact:
- **Risk**: Performance degradation
- **Mitigation**: Performance monitoring and optimization
- **Testing**: Performance benchmarking

## Success Metrics

1. **Code Quality**:
   - Test coverage > 80%
   - Cyclomatic complexity < 10
   - Maintainability index > 70

2. **Performance**:
   - App startup time < 3 seconds
   - Memory usage < 200MB
   - Smooth UI transitions

3. **User Experience**:
   - No data loss during migration
   - All features working as expected
   - Improved app stability

## Timeline

- **Week 1-2**: Foundation setup
- **Week 3-6**: Feature migration
- **Week 7-8**: Integration and testing
- **Week 9-10**: Optimization and launch

## Next Steps

1. Review and approve this migration plan
2. Set up development environment for DCL2
3. Begin Phase 1 implementation
4. Regular progress reviews and adjustments

This migration plan ensures a smooth transition from DCL1 to DCL2 while maintaining application stability and user data integrity.
