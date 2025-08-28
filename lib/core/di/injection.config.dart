// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:hive/hive.dart' as _i979;
import 'package:injectable/injectable.dart' as _i526;
import 'package:sqflite/sqflite.dart' as _i779;

import '../../data/datasources/local/light_novel_local_data_source.dart'
    as _i582;
import '../../data/datasources/remote/light_novel_remote_data_source.dart'
    as _i933;
import '../../data/repositories/light_novel_repository_impl.dart' as _i623;
import '../../domain/repositories/light_novel_repository.dart' as _i790;
import '../../domain/usecases/get_light_novel.dart' as _i258;
import '../../domain/usecases/get_light_novels.dart' as _i122;
import '../../domain/usecases/search_light_novels.dart' as _i785;
import '../../presentation/blocs/light_novel/light_novel_bloc.dart' as _i32;
import '../network/api_client.dart' as _i557;
import '../network/network_info.dart' as _i932;
import 'modules/data_module.dart' as _i742;

// initializes the registration of main-scope dependencies inside of GetIt
Future<_i174.GetIt> $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) async {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  final dataModule = _$DataModule();
  gh.lazySingleton<_i361.Dio>(() => dataModule.dio);
  gh.lazySingleton<_i895.Connectivity>(() => dataModule.connectivity);
  await gh.lazySingletonAsync<_i779.Database>(
    () => dataModule.database,
    preResolve: true,
  );
  await gh.lazySingletonAsync<_i979.Box<dynamic>>(
    () => dataModule.hiveBox,
    preResolve: true,
  );
  gh.lazySingleton<_i932.NetworkInfo>(
      () => dataModule.networkInfo(gh<_i895.Connectivity>()));
  gh.lazySingleton<_i557.ApiClient>(() => dataModule.apiClient(
        gh<_i361.Dio>(),
        gh<_i895.Connectivity>(),
      ));
  gh.factory<_i582.LightNovelLocalDataSource>(
      () => _i582.LightNovelLocalDataSourceImpl(gh<_i779.Database>()));
  gh.factory<_i933.LightNovelRemoteDataSource>(
      () => _i933.LightNovelRemoteDataSourceImpl(gh<_i557.ApiClient>()));
  gh.factory<_i790.LightNovelRepository>(() => _i623.LightNovelRepositoryImpl(
        gh<_i933.LightNovelRemoteDataSource>(),
        gh<_i582.LightNovelLocalDataSource>(),
        gh<_i557.ApiClient>(),
      ));
  gh.factory<_i258.GetLightNovelUseCase>(
      () => _i258.GetLightNovelUseCase(gh<_i790.LightNovelRepository>()));
  gh.factory<_i122.GetLightNovelsUseCase>(
      () => _i122.GetLightNovelsUseCase(gh<_i790.LightNovelRepository>()));
  gh.factory<_i785.SearchLightNovelsUseCase>(
      () => _i785.SearchLightNovelsUseCase(gh<_i790.LightNovelRepository>()));
  gh.factory<_i32.LightNovelBloc>(() => _i32.LightNovelBloc(
        gh<_i122.GetLightNovelsUseCase>(),
        gh<_i258.GetLightNovelUseCase>(),
        gh<_i785.SearchLightNovelsUseCase>(),
      ));
  return getIt;
}

class _$DataModule extends _i742.DataModule {}
