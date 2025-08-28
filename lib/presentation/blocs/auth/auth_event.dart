part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthGetCurrentUserRequested extends AuthEvent {
  const AuthGetCurrentUserRequested();
}

class AuthWatchStateRequested extends AuthEvent {
  const AuthWatchStateRequested();
}

class AuthStateChanged extends AuthEvent {
  final UserEntity? user;
  final String? error;

  const AuthStateChanged({
    this.user,
    this.error,
  });

  @override
  List<Object?> get props => [user, error];
}
