import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

abstract class BaseBloc<Event, State> extends Bloc<Event, State> {
  BaseBloc(State initialState) : super(initialState);

  @override
  void onError(Object error, StackTrace stackTrace) {
    // Log error - in a real app, you'd use a logging service
    print('[BLoC Error] $error');
    print('[BLoC StackTrace] $stackTrace');
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
