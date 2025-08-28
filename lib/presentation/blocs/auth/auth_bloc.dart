import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../core/usecases/usecase.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/auth_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@Injectable()
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final WatchAuthStateUseCase _watchAuthStateUseCase;

  StreamSubscription? _authStateSubscription;

  AuthBloc(
    this._signInUseCase,
    this._signUpUseCase,
    this._signOutUseCase,
    this._getCurrentUserUseCase,
    this._watchAuthStateUseCase,
  ) : super(AuthInitial()) {
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthGetCurrentUserRequested>(_onGetCurrentUserRequested);
    on<AuthWatchStateRequested>(_onWatchStateRequested);
    on<AuthStateChanged>(_onAuthStateChanged);
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInUseCase(
      SignInParams(
        email: event.email,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signUpUseCase(
      SignUpParams(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signOutUseCase(NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  Future<void> _onGetCurrentUserRequested(
    AuthGetCurrentUserRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _getCurrentUserUseCase(NoParams());

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(user != null ? AuthAuthenticated(user) : AuthUnauthenticated()),
    );
  }

  Future<void> _onWatchStateRequested(
    AuthWatchStateRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authStateSubscription?.cancel();

    _authStateSubscription = _watchAuthStateUseCase(NoParams()).listen(
      (result) {
        result.fold(
          (failure) => add(AuthStateChanged(error: failure.message)),
          (user) => add(AuthStateChanged(user: user)),
        );
      },
      onError: (error) => add(AuthStateChanged(error: error.toString())),
    );
  }

  void _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.error != null) {
      emit(AuthError(event.error!));
    } else {
      emit(event.user != null ? AuthAuthenticated(event.user!) : AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
