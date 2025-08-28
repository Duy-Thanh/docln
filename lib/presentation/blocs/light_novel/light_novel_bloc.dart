import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_light_novels.dart';
import '../../../domain/usecases/get_light_novel.dart';
import '../../../domain/usecases/search_light_novels.dart';
import '../base/base_bloc.dart';
import 'light_novel_event.dart';
import 'light_novel_state.dart';

@Injectable()
class LightNovelBloc extends BaseBloc<LightNovelEvent, LightNovelState> {
  final GetLightNovelsUseCase _getLightNovelsUseCase;
  final GetLightNovelUseCase _getLightNovelUseCase;
  final SearchLightNovelsUseCase _searchLightNovelsUseCase;

  LightNovelBloc(
    this._getLightNovelsUseCase,
    this._getLightNovelUseCase,
    this._searchLightNovelsUseCase,
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
    // This would typically call a save use case
  }

  Future<void> _onRemoveLightNovel(
    RemoveLightNovel event,
    Emitter<LightNovelState> emit,
  ) async {
    // Implementation for removing light novel
    // This would typically call a remove use case
  }
}
