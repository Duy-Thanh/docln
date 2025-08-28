import '../../../domain/entities/light_novel.dart';
import '../base/base_bloc.dart';

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
