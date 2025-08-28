# DocLN DCL2 - Clean Architecture Implementation

## Overview

DCL2 is the new clean architecture implementation of DocLN, replacing the legacy DCL1 architecture. This implementation follows Clean Architecture principles with clear separation of concerns, dependency injection, and BLoC pattern for state management.

## Architecture Overview

```
lib/
├── core/                    # Core functionality and shared utilities
│   ├── di/                 # Dependency Injection
│   │   ├── injection.dart
│   │   ├── injection.config.dart (generated)
│   │   └── modules/
│   ├── error/              # Error handling
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/            # Network layer
│   │   ├── api_client.dart
│   │   └── network_info.dart
│   └── usecases/           # Base use case classes
├── data/                   # Data layer
│   ├── datasources/        # Data source implementations
│   │   ├── local/
│   │   └── remote/
│   ├── models/             # Data transfer objects
│   └── repositories/       # Repository implementations
├── domain/                 # Domain layer (Business Logic)
│   ├── entities/           # Business entities
│   ├── repositories/       # Repository contracts
│   └── usecases/           # Application use cases
├── presentation/           # Presentation layer (UI)
│   ├── blocs/              # BLoC state management
│   │   ├── base/
│   │   └── light_novel/
│   ├── pages/              # Screen widgets
│   ├── widgets/            # Reusable UI components
│   └── themes/             # App themes
└── features/               # Feature modules (future)
```

## Key Principles

### 1. **Clean Architecture**
- **Domain Layer**: Contains business logic and is independent of frameworks
- **Data Layer**: Implements domain contracts and handles data operations
- **Presentation Layer**: Manages UI and user interactions

### 2. **Dependency Inversion**
- High-level modules don't depend on low-level modules
- Both depend on abstractions (interfaces)
- Repository pattern for data access abstraction

### 3. **SOLID Principles**
- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Subtypes are substitutable for their base types
- **Interface Segregation**: Clients depend only on methods they use
- **Dependency Inversion**: Depend on abstractions, not concretions

### 4. **BLoC Pattern**
- Predictable state management
- Separation of business logic from UI
- Easy testing and debugging

## Core Components

### Domain Layer

#### Entities
```dart
class LightNovelEntity extends Equatable {
  final String id;
  final String title;
  final String coverUrl;
  final String url;
  // ... other properties
}
```

#### Use Cases
```dart
@injectable
class GetLightNovelsUseCase implements UseCase<List<LightNovelEntity>, GetLightNovelsParams> {
  final LightNovelRepository _repository;

  @override
  Future<Either<Failure, List<LightNovelEntity>>> call(GetLightNovelsParams params) {
    return _repository.getLightNovels(page: params.page, limit: params.limit);
  }
}
```

#### Repository Contracts
```dart
abstract class LightNovelRepository {
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels();
  Future<Either<Failure, LightNovelEntity>> getLightNovel(String id);
  // ... other methods
}
```

### Data Layer

#### Repository Implementation
```dart
@Injectable(as: LightNovelRepository)
class LightNovelRepositoryImpl implements LightNovelRepository {
  final LightNovelRemoteDataSource _remoteDataSource;
  final LightNovelLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels() async {
    try {
      // Try cache first, then remote
      final cached = await _localDataSource.getCachedLightNovels();
      if (cached.isNotEmpty) return Right(cached);

      final remote = await _remoteDataSource.getLightNovels();
      await _localDataSource.cacheLightNovels(remote);
      return Right(remote);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
```

#### Data Sources
```dart
@Injectable(as: LightNovelRemoteDataSource)
class LightNovelRemoteDataSourceImpl implements LightNovelRemoteDataSource {
  final ApiClient _apiClient;

  @override
  Future<List<LightNovelModel>> getLightNovels() async {
    final response = await _apiClient.dio.get('/api/light-novels');
    return (response.data as List)
        .map((json) => LightNovelModel.fromJson(json))
        .toList();
  }
}
```

### Presentation Layer

#### BLoC Implementation
```dart
@Injectable()
class LightNovelBloc extends Bloc<LightNovelEvent, LightNovelState> {
  final GetLightNovelsUseCase _getLightNovelsUseCase;

  LightNovelBloc(this._getLightNovelsUseCase) : super(const LightNovelInitial()) {
    on<LoadLightNovels>(_onLoadLightNovels);
  }

  Future<void> _onLoadLightNovels(LoadLightNovels event, Emitter<LightNovelState> emit) async {
    emit(const LightNovelLoading());
    final result = await _getLightNovelsUseCase(event.params);
    result.fold(
      (failure) => emit(LightNovelError(failure.message)),
      (novels) => emit(LightNovelLoaded(novels)),
    );
  }
}
```

#### UI Implementation
```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LightNovelBloc, LightNovelState>(
      builder: (context, state) {
        if (state is LightNovelLoading) {
          return const CircularProgressIndicator();
        } else if (state is LightNovelLoaded) {
          return ListView.builder(
            itemCount: state.novels.length,
            itemBuilder: (context, index) => NovelCard(state.novels[index]),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
```

## Dependency Injection

### Setup
```dart
// main_dcl2.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies(); // Generated by injectable
  runApp(const DCL2App());
}
```

### Module Registration
```dart
@module
abstract class DataModule {
  @lazySingleton
  Dio get dio => Dio();

  @lazySingleton
  ApiClient apiClient(Dio dio, Connectivity connectivity) =>
      ApiClient(dio, connectivity);

  @preResolve
  @lazySingleton
  Future<Database> get database async => openDatabase(...);
}
```

## Error Handling

### Failure Types
```dart
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}
```

### Error Propagation
```dart
// Domain -> Data -> Presentation
Either<Failure, T> result = await useCase(params);
result.fold(
  (failure) => emit(ErrorState(failure.message)),
  (data) => emit(DataLoadedState(data)),
);
```

## Testing Strategy

### Unit Tests
```dart
void main() {
  test('should get light novels from repository', () async {
    final mockRepo = MockLightNovelRepository();
    final useCase = GetLightNovelsUseCase(mockRepo);

    when(mockRepo.getLightNovels())
        .thenAnswer((_) async => Right(testNovels));

    final result = await useCase(NoParams());
    expect(result, Right(testNovels));
  });
}
```

### Widget Tests
```dart
void main() {
  testWidgets('should display loading then novels', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);
  });
}
```

## Migration from DCL1

### Gradual Migration Strategy
1. **Phase 1**: Foundation (✅ Complete)
   - Set up new architecture
   - Create core components
   - Implement domain layer

2. **Phase 2**: Feature Migration (Next)
   - Migrate authentication
   - Migrate library management
   - Migrate reader functionality

3. **Phase 3**: Integration & Testing
   - Integrate all features
   - Test data migration
   - Performance optimization

### Running DCL2
```bash
# Run DCL2 (new architecture)
flutter run lib/main_dcl2.dart

# Run DCL1 (legacy architecture)
flutter run lib/main.dart
```

## Benefits of DCL2

### Maintainability
- Clear separation of concerns
- Single responsibility principle
- Easy to locate and modify code

### Testability
- 100% testable architecture
- Dependency injection enables mocking
- Isolated unit tests

### Scalability
- Easy to add new features
- Modular architecture
- Independent layers

### Performance
- Efficient state management
- Smart caching strategies
- Optimized data flow

### Developer Experience
- Clear code organization
- Consistent patterns
- Better debugging

## Future Enhancements

### Planned Features
- [ ] Authentication BLoC
- [ ] Chapter reader with pagination
- [ ] Offline reading capabilities
- [ ] Advanced search and filtering
- [ ] User preferences management
- [ ] Push notifications
- [ ] Social features (comments, ratings)

### Technical Improvements
- [ ] GraphQL API integration
- [ ] Advanced caching with Hive
- [ ] CI/CD pipeline
- [ ] Automated testing
- [ ] Performance monitoring
- [ ] Error tracking and analytics

## Contributing

When adding new features:
1. Create domain entities first
2. Implement use cases
3. Create repository contracts
4. Implement data sources
5. Add BLoC for state management
6. Create UI components
7. Add comprehensive tests

## Documentation

- [Migration Guide](./DCL2_MIGRATION_PLAN.md)
- [Implementation Guide](./DCL2_IMPLEMENTATION_GUIDE.md)
- [Architecture Comparison](./DCL1_DCL2_COMPARISON.md)

---

**DCL2 Status**: Phase 1 Complete ✅ | Ready for Phase 2
