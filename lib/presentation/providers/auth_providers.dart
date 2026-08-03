import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_token_storage.dart';
import '../../data/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final Provider<SecureTokenStorage> secureTokenStorageProvider = Provider<SecureTokenStorage>((Ref ref) {
  return SecureTokenStorage();
});

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(tokenStorage: ref.watch(secureTokenStorageProvider));
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restoreSession);
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    final user = await _repository.restoreSession();
    state = user != null ? AuthState.authenticated(user) : const AuthState.unauthenticated();
  }

  Future<void> register({required String email, required String password, required String name}) {
    return _submit(() => _repository.register(email: email, password: password, name: name));
  }

  Future<void> login({required String email, required String password}) {
    return _submit(() => _repository.login(email: email, password: password));
  }

  Future<void> loginAsGuest() => _submit(_repository.loginAsGuest);

  Future<void> loginWithGoogle() => _submit(_repository.loginWithGoogle);

  Future<void> loginWithApple() => _submit(_repository.loginWithApple);

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repository.forgotPassword(email);
      state = state.copyWith(isSubmitting: false);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: _friendlyError(error));
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.unauthenticated();
  }

  Future<void> _submit(Future<User> Function() action) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final user = await action();
      state = AuthState.authenticated(user);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        if (message is String) return message;
        if (message is Map && message['message'] is String) return message['message'] as String;
        if (message is List && message.isNotEmpty) return message.first.toString();
      }
      return 'Network error. Please try again.';
    }
    return error.toString();
  }
}
