import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/storage/secure_token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../network/api_client.dart';

/// *** SET YOUR REAL OAUTH CLIENT IDs HERE ***
/// Required for [AuthRepositoryImpl.loginWithGoogle] /
/// [AuthRepositoryImpl.loginWithApple] to work — the flows themselves are
/// fully implemented against the real Google/Apple SDKs.
abstract final class SocialAuthConfig {
  static const String googleClientId = '';
  static const String googleServerClientId = '';
  static const String appleServiceId = '';
  static const String appleRedirectUri = '';
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this._apiClient, required this._tokenStorage});

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  @override
  Future<User?> restoreSession() async {
    final String? accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) return null;

    try {
      final Response<Map<String, dynamic>> response =
          await _apiClient.dio.get<Map<String, dynamic>>('/users/me');
      return _userFromJson(response.data!);
    } on DioException catch (error) {
      // Only a genuine 401 means this token is actually invalid/expired —
      // clearing storage on any other failure (offline, timeout, backend
      // down) would silently burn this identity and force a brand-new
      // guest account next launch, orphaning whatever robots the real
      // account already owns.
      if (error.response?.statusCode == 401) {
        await _tokenStorage.clear();
      }
      return null;
    }
  }

  @override
  Future<User> register({required String email, required String password, required String name}) async {
    final Response<Map<String, dynamic>> response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password, 'name': name},
    );
    return _completeLogin(response.data!);
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final Response<Map<String, dynamic>> response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _completeLogin(response.data!);
  }

  @override
  Future<User> loginAsGuest() async {
    final Response<Map<String, dynamic>> response =
        await _apiClient.dio.post<Map<String, dynamic>>('/auth/guest');
    return _completeLogin(response.data!);
  }

  @override
  Future<User> loginWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      clientId: SocialAuthConfig.googleClientId.isEmpty ? null : SocialAuthConfig.googleClientId,
      serverClientId:
          SocialAuthConfig.googleServerClientId.isEmpty ? null : SocialAuthConfig.googleServerClientId,
    );
    final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an ID token');
    }

    final Response<Map<String, dynamic>> response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/google',
      data: {'idToken': idToken},
    );
    return _completeLogin(response.data!);
  }

  @override
  Future<User> loginWithApple() async {
    final AuthorizationCredentialAppleID credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      webAuthenticationOptions: SocialAuthConfig.appleServiceId.isEmpty
          ? null
          : WebAuthenticationOptions(
              clientId: SocialAuthConfig.appleServiceId,
              redirectUri: Uri.parse(SocialAuthConfig.appleRedirectUri),
            ),
    );

    final String? idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple did not return an identity token');
    }

    final Response<Map<String, dynamic>> response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/apple',
      data: {'idToken': idToken},
    );
    return _completeLogin(response.data!);
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _apiClient.dio.post<Map<String, dynamic>>('/auth/forgot-password', data: {'email': email});
  }

  @override
  Future<void> logout() => _tokenStorage.clear();

  Future<User> _completeLogin(Map<String, dynamic> tokenResponse) async {
    final String accessToken = tokenResponse['accessToken'] as String;
    final String refreshToken = tokenResponse['refreshToken'] as String;
    await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    final Response<Map<String, dynamic>> meResponse =
        await _apiClient.dio.post<Map<String, dynamic>>('/auth/me');
    return _userFromJson(meResponse.data!);
  }

  User _userFromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String,
    );
  }
}
