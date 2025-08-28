import '../base/base_bloc.dart';

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
