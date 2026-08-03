import '../entities/user.dart';

abstract class AuthRepository {
  /// Restores a session from securely-stored tokens, if any exist and are
  /// still valid. Returns null if there is no session to restore.
  Future<User?> restoreSession();

  Future<User> register({required String email, required String password, required String name});

  Future<User> login({required String email, required String password});

  Future<User> loginAsGuest();

  Future<User> loginWithGoogle();

  Future<User> loginWithApple();

  Future<void> forgotPassword(String email);

  Future<void> logout();
}
