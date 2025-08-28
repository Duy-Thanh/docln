# DCL2 Architecture Implementation Guide

## Phase 1: Foundation Setup

### Step 1: Directory Structure Setup

Create the new architecture directories:

```
lib/
├── core/
│   ├── di/                 # Dependency Injection
│   │   ├── injection.dart
│   │   └── modules/
│   │       ├── data_module.dart
│   │       ├── domain_module.dart
│   │       └── presentation_module.dart
│   ├── error/
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   └── network_info.dart
│   └── usecases/
│       └── usecase.dart
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   └── remote/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/
│   ├── blocs/
│   ├── pages/
│   ├── widgets/
│   └── themes/
└── features/
    ├── auth/
    ├── library/
    ├── reader/
    └── search/
```

### Step 2: Core Dependencies Setup

Update `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.3
  bloc: ^8.1.2

  # Dependency Injection
  injectable: ^2.4.1
  get_it: ^7.6.7

  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.3

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # Utilities
  equatable: ^2.0.5
  dartz: ^0.10.1
  path_provider: ^2.1.3

  # Existing dependencies (keep for migration)
  supabase_flutter: ^2.9.1
  sqflite: ^2.4.2
  shared_preferences: ^2.5.3

dev_dependencies:
  build_runner: ^2.4.8
  injectable_generator: ^2.6.1
  hive_generator: ^2.0.1
```

### Step 3: Core Architecture Components

#### 3.1 Base Classes

Create `core/usecases/usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../error/failures.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}

abstract class StreamUseCase<Type, Params> {
  Stream<Either<Failure, Type>> call(Params params);
}
```

Create `core/error/failures.dart`:

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

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
```

Create `core/error/exceptions.dart`:

```dart
class ServerException implements Exception {
  final String message;

  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;

  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);
}
```

#### 3.2 Network Layer

Create `core/network/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiClient {
  final Dio _dio;
  final Connectivity _connectivity;

  ApiClient(this._dio, this._connectivity) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: 'https://ln.hako.vn',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'DocLN/1.0',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.addAll([
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    ]);
  }

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Dio get dio => _dio;
}
```

#### 3.3 Dependency Injection Setup

Create `core/di/injection.dart`:

```dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
void configureDependencies() => $initGetIt(getIt);
```

Create `core/di/modules/data_module.dart`:

```dart
import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

@module
abstract class DataModule {
  @lazySingleton
  Dio get dio => Dio();

  @lazySingleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  ApiClient apiClient(Dio dio, Connectivity connectivity) =>
      ApiClient(dio, connectivity);

  @preResolve
  @lazySingleton
  Future<Database> get database async {
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/docln.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create tables
        await db.execute('''
          CREATE TABLE light_novels (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cover_url TEXT,
            url TEXT NOT NULL,
            chapters INTEGER,
            latest_chapter TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
    );
  }

  @preResolve
  @lazySingleton
  Future<Box> get hiveBox async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    return await Hive.openBox('docln_cache');
  }
}
```

### Step 4: Domain Layer Implementation

#### 4.1 Domain Entities

Create `domain/entities/light_novel.dart`:

```dart
import 'package:equatable/equatable.dart';

class LightNovelEntity extends Equatable {
  final String id;
  final String title;
  final String coverUrl;
  final String url;
  final int? chapters;
  final String? latestChapter;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LightNovelEntity({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
    this.chapters,
    this.latestChapter,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        coverUrl,
        url,
        chapters,
        latestChapter,
        createdAt,
        updatedAt,
      ];
}
```

#### 4.2 Repository Contracts

Create `domain/repositories/light_novel_repository.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/light_novel.dart';

abstract class LightNovelRepository {
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, LightNovelEntity>> getLightNovel(String id);

  Future<Either<Failure, void>> saveLightNovel(LightNovelEntity novel);

  Future<Either<Failure, void>> removeLightNovel(String id);

  Future<Either<Failure, List<LightNovelEntity>>> searchLightNovels(
    String query,
  );

  Stream<Either<Failure, List<LightNovelEntity>>> watchLightNovels();
}
```

#### 4.3 Use Cases

Create `domain/usecases/get_light_novels.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/light_novel.dart';
import '../repositories/light_novel_repository.dart';

class GetLightNovelsParams extends Equatable {
  final int page;
  final int limit;

  const GetLightNovelsParams({
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [page, limit];
}

@injectable
class GetLightNovelsUseCase
    implements UseCase<List<LightNovelEntity>, GetLightNovelsParams> {
  final LightNovelRepository _repository;

  GetLightNovelsUseCase(this._repository);

  @override
  Future<Either<Failure, List<LightNovelEntity>>> call(
    GetLightNovelsParams params,
  ) async {
    return await _repository.getLightNovels(
      page: params.page,
      limit: params.limit,
    );
  }
}
```

### Step 5: Data Layer Implementation

#### 5.1 Data Models

Create `data/models/light_novel_model.dart`:

```dart
import '../../domain/entities/light_novel.dart';

class LightNovelModel extends LightNovelEntity {
  const LightNovelModel({
    required super.id,
    required super.title,
    required super.coverUrl,
    required super.url,
    super.chapters,
    super.latestChapter,
    super.createdAt,
    super.updatedAt,
  });

  factory LightNovelModel.fromJson(Map<String, dynamic> json) {
    return LightNovelModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverUrl: json['coverUrl'] ?? 'https://ln.hako.vn/img/nocover.jpg',
      url: json['url'] ?? '',
      chapters: json['chapters'],
      latestChapter: json['latestChapter'],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'url': url,
      'chapters': chapters,
      'latestChapter': latestChapter,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory LightNovelModel.fromEntity(LightNovelEntity entity) {
    return LightNovelModel(
      id: entity.id,
      title: entity.title,
      coverUrl: entity.coverUrl,
      url: entity.url,
      chapters: entity.chapters,
      latestChapter: entity.latestChapter,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
```

#### 5.2 Data Sources

Create `data/datasources/remote/light_novel_remote_data_source.dart`:

```dart
import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../models/light_novel_model.dart';

abstract class LightNovelRemoteDataSource {
  Future<List<LightNovelModel>> getLightNovels({
    required int page,
    required int limit,
  });

  Future<LightNovelModel> getLightNovel(String id);
}

@Injectable(as: LightNovelRemoteDataSource)
class LightNovelRemoteDataSourceImpl implements LightNovelRemoteDataSource {
  final ApiClient _apiClient;

  LightNovelRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<LightNovelModel>> getLightNovels({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/light-novels',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data as List;
      return data.map((json) => LightNovelModel.fromJson(json)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch light novels: ${e.toString()}');
    }
  }

  @override
  Future<LightNovelModel> getLightNovel(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/light-novels/$id');
      return LightNovelModel.fromJson(response.data);
    } catch (e) {
      throw ServerException('Failed to fetch light novel: ${e.toString()}');
    }
  }
}
```

Create `data/datasources/local/light_novel_local_data_source.dart`:

```dart
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/exceptions.dart';
import '../../models/light_novel_model.dart';

abstract class LightNovelLocalDataSource {
  Future<List<LightNovelModel>> getCachedLightNovels();
  Future<LightNovelModel?> getCachedLightNovel(String id);
  Future<void> cacheLightNovels(List<LightNovelModel> novels);
  Future<void> cacheLightNovel(LightNovelModel novel);
  Future<void> removeLightNovel(String id);
}

@Injectable(as: LightNovelLocalDataSource)
class LightNovelLocalDataSourceImpl implements LightNovelLocalDataSource {
  final Database _database;

  LightNovelLocalDataSourceImpl(this._database);

  @override
  Future<List<LightNovelModel>> getCachedLightNovels() async {
    try {
      final maps = await _database.query(
        'light_novels',
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => LightNovelModel.fromJson(map)).toList();
    } catch (e) {
      throw CacheException('Failed to get cached light novels: ${e.toString()}');
    }
  }

  @override
  Future<LightNovelModel?> getCachedLightNovel(String id) async {
    try {
      final maps = await _database.query(
        'light_novels',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return LightNovelModel.fromJson(maps.first);
    } catch (e) {
      throw CacheException('Failed to get cached light novel: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheLightNovels(List<LightNovelModel> novels) async {
    final batch = _database.batch();

    for (final novel in novels) {
      batch.insert(
        'light_novels',
        novel.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<void> cacheLightNovel(LightNovelModel novel) async {
    await _database.insert(
      'light_novels',
      novel.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeLightNovel(String id) async {
    await _database.delete(
      'light_novels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

#### 5.3 Repository Implementation

Create `data/repositories/light_novel_repository_impl.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/light_novel.dart';
import '../../domain/repositories/light_novel_repository.dart';
import '../datasources/local/light_novel_local_data_source.dart';
import '../datasources/remote/light_novel_remote_data_source.dart';
import '../models/light_novel_model.dart';

@Injectable(as: LightNovelRepository)
class LightNovelRepositoryImpl implements LightNovelRepository {
  final LightNovelRemoteDataSource _remoteDataSource;
  final LightNovelLocalDataSource _localDataSource;
  final ApiClient _apiClient;

  LightNovelRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._apiClient,
  );

  @override
  Future<Either<Failure, List<LightNovelEntity>>> getLightNovels({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Try to get from cache first
      final cachedNovels = await _localDataSource.getCachedLightNovels();

      // If we have cached data and no internet, return cached data
      if (cachedNovels.isNotEmpty && !(await _apiClient.isConnected)) {
        return Right(cachedNovels);
      }

      // Try to fetch from remote
      final remoteNovels = await _remoteDataSource.getLightNovels(
        page: page,
        limit: limit,
      );

      // Cache the remote data
      await _localDataSource.cacheLightNovels(remoteNovels);

      return Right(remoteNovels);
    } on ServerException catch (e) {
      // If server fails and we have cache, return cache
      try {
        final cachedNovels = await _localDataSource.getCachedLightNovels();
        if (cachedNovels.isNotEmpty) {
          return Right(cachedNovels);
        }
      } catch (_) {
        // Cache also failed
      }
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, LightNovelEntity>> getLightNovel(String id) async {
    try {
      // Try cache first
      final cachedNovel = await _localDataSource.getCachedLightNovel(id);
      if (cachedNovel != null) {
        return Right(cachedNovel);
      }

      // Fetch from remote
      final remoteNovel = await _remoteDataSource.getLightNovel(id);

      // Cache the result
      await _localDataSource.cacheLightNovel(remoteNovel);

      return Right(remoteNovel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> saveLightNovel(LightNovelEntity novel) async {
    try {
      final model = LightNovelModel.fromEntity(novel);
      await _localDataSource.cacheLightNovel(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeLightNovel(String id) async {
    try {
      await _localDataSource.removeLightNovel(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<LightNovelEntity>>> searchLightNovels(
    String query,
  ) async {
    try {
      // For now, search in local cache
      // In a real implementation, you might want to search remotely
      final cachedNovels = await _localDataSource.getCachedLightNovels();
      final filteredNovels = cachedNovels
          .where((novel) =>
              novel.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return Right(filteredNovels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<LightNovelEntity>>> watchLightNovels() async* {
    // This would typically use a stream from the database
    // For simplicity, we'll emit the current cached data
    try {
      final novels = await _localDataSource.getCachedLightNovels();
      yield Right(novels);
    } on CacheException catch (e) {
      yield Left(CacheFailure(e.message));
    }
  }
}
```

### Step 6: Presentation Layer Setup

#### 6.1 BLoC Base Classes

Create `presentation/blocs/base/base_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

abstract class BaseBloc<Event, State> extends Bloc<Event, State> {
  BaseBloc(State initialState) : super(initialState);

  @override
  void onError(Object error, StackTrace stackTrace) {
    // Log error
    super.onError(error, stackTrace);
  }
}

abstract class BaseEvent extends Equatable {
  const BaseEvent();

  @override
  List<Object?> get props => [];
}

abstract class BaseState extends Equatable {
  const BaseState();

  @override
  List<Object?> get props => [];
}
```

#### 6.2 Light Novel BLoC

Create `presentation/blocs/light_novel/light_novel_event.dart`:

```dart
import '../../../core/usecases/usecase.dart';
import 'base/base_bloc.dart';

abstract class LightNovelEvent extends BaseEvent {
  const LightNovelEvent();
}

class LoadLightNovels extends LightNovelEvent {
  final int page;
  final int limit;

  const LoadLightNovels({
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [page, limit];
}

class LoadLightNovel extends LightNovelEvent {
  final String id;

  const LoadLightNovel(this.id);

  @override
  List<Object?> get props => [id];
}

class SearchLightNovels extends LightNovelEvent {
  final String query;

  const SearchLightNovels(this.query);

  @override
  List<Object?> get props => [query];
}

class SaveLightNovel extends LightNovelEvent {
  final String id;

  const SaveLightNovel(this.id);

  @override
  List<Object?> get props => [id];
}

class RemoveLightNovel extends LightNovelEvent {
  final String id;

  const RemoveLightNovel(this.id);

  @override
  List<Object?> get props => [id];
}
```

Create `presentation/blocs/light_novel/light_novel_state.dart`:

```dart
import '../../../domain/entities/light_novel.dart';
import 'base/base_bloc.dart';

abstract class LightNovelState extends BaseState {
  const LightNovelState();
}

class LightNovelInitial extends LightNovelState {
  const LightNovelInitial();
}

class LightNovelLoading extends LightNovelState {
  const LightNovelLoading();
}

class LightNovelLoaded extends LightNovelState {
  final List<LightNovelEntity> novels;
  final bool hasReachedMax;

  const LightNovelLoaded(this.novels, {this.hasReachedMax = false});

  @override
  List<Object?> get props => [novels, hasReachedMax];
}

class LightNovelDetailLoaded extends LightNovelState {
  final LightNovelEntity novel;

  const LightNovelDetailLoaded(this.novel);

  @override
  List<Object?> get props => [novel];
}

class LightNovelError extends LightNovelState {
  final String message;

  const LightNovelError(this.message);

  @override
  List<Object?> get props => [message];
}
```

Create `presentation/blocs/light_novel/light_novel_bloc.dart`:

```dart
import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_light_novels.dart';
import '../../../domain/usecases/get_light_novel.dart';
import '../../../domain/usecases/search_light_novels.dart';
import '../../../domain/usecases/save_light_novel.dart';
import '../../../domain/usecases/remove_light_novel.dart';
import 'base/base_bloc.dart';
import 'light_novel_event.dart';
import 'light_novel_state.dart';

@Injectable()
class LightNovelBloc extends BaseBloc<LightNovelEvent, LightNovelState> {
  final GetLightNovelsUseCase _getLightNovelsUseCase;
  final GetLightNovelUseCase _getLightNovelUseCase;
  final SearchLightNovelsUseCase _searchLightNovelsUseCase;
  final SaveLightNovelUseCase _saveLightNovelUseCase;
  final RemoveLightNovelUseCase _removeLightNovelUseCase;

  LightNovelBloc(
    this._getLightNovelsUseCase,
    this._getLightNovelUseCase,
    this._searchLightNovelsUseCase,
    this._saveLightNovelUseCase,
    this._removeLightNovelUseCase,
  ) : super(const LightNovelInitial()) {
    on<LoadLightNovels>(_onLoadLightNovels);
    on<LoadLightNovel>(_onLoadLightNovel);
    on<SearchLightNovels>(_onSearchLightNovels);
    on<SaveLightNovel>(_onSaveLightNovel);
    on<RemoveLightNovel>(_onRemoveLightNovel);
  }

  Future<void> _onLoadLightNovels(
    LoadLightNovels event,
    Emitter<LightNovelState> emit,
  ) async {
    emit(const LightNovelLoading());

    final result = await _getLightNovelsUseCase(
      GetLightNovelsParams(
        page: event.page,
        limit: event.limit,
      ),
    );

    result.fold(
      (failure) => emit(LightNovelError(failure.message)),
      (novels) => emit(LightNovelLoaded(novels)),
    );
  }

  Future<void> _onLoadLightNovel(
    LoadLightNovel event,
    Emitter<LightNovelState> emit,
  ) async {
    emit(const LightNovelLoading());

    final result = await _getLightNovelUseCase(event.id);

    result.fold(
      (failure) => emit(LightNovelError(failure.message)),
      (novel) => emit(LightNovelDetailLoaded(novel)),
    );
  }

  Future<void> _onSearchLightNovels(
    SearchLightNovels event,
    Emitter<LightNovelState> emit,
  ) async {
    emit(const LightNovelLoading());

    final result = await _searchLightNovelsUseCase(event.query);

    result.fold(
      (failure) => emit(LightNovelError(failure.message)),
      (novels) => emit(LightNovelLoaded(novels)),
    );
  }

  Future<void> _onSaveLightNovel(
    SaveLightNovel event,
    Emitter<LightNovelState> emit,
  ) async {
    // Implementation for saving light novel
  }

  Future<void> _onRemoveLightNovel(
    RemoveLightNovel event,
    Emitter<LightNovelState> emit,
  ) async {
    // Implementation for removing light novel
  }
}
```

### Step 7: Update main.dart for DCL2

Create a new main_dcl2.dart file to test the new architecture:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'presentation/blocs/light_novel/light_novel_bloc.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dependencies
  configureDependencies();

  runApp(const DCL2App());
}

class DCL2App extends StatelessWidget {
  const DCL2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LightNovelBloc>(
          create: (context) => getIt<LightNovelBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'DocLN DCL2',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
```

### Step 8: Generate Dependency Injection

Run the following commands to generate the DI code:

```bash
flutter pub run build_runner build
```

This will generate the `injection.config.dart` file with all the dependency injection setup.

## Next Steps

1. **Test the Foundation**: Run the new main_dcl2.dart to ensure the basic architecture works
2. **Create UI Components**: Build the presentation layer widgets
3. **Migrate Authentication**: Move to Phase 2 of the migration plan
4. **Gradual Migration**: Slowly migrate features from DCL1 to DCL2

## Benefits of This Architecture

1. **Testability**: Each layer can be unit tested independently
2. **Maintainability**: Clear separation of concerns
3. **Scalability**: Easy to add new features
4. **Flexibility**: Easy to swap implementations (e.g., different data sources)
5. **Performance**: Better state management and caching
6. **Developer Experience**: Clear code organization and patterns

This foundation provides a solid base for the complete DCL2 migration while maintaining compatibility with the existing DCL1 codebase during the transition period.
