import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({String? errorMessage})
      : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  const AuthState.authenticated(User user) : this(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final User? user;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({bool? isSubmitting, String? errorMessage, bool clearError = false}) {
    return AuthState(
      status: status,
      user: user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, errorMessage];
}
