import 'package:dio/dio.dart';

import '../../core/constants/backend_config.dart';
import '../../core/storage/secure_token_storage.dart';

/// Thin wrapper around [Dio] that attaches the current access token to every
/// request and transparently refreshes + retries once on a 401.
class ApiClient {
  ApiClient({required this._tokenStorage, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: BackendConfig.apiBaseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await _tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final bool isAuthEndpoint = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isAuthEndpoint && !_isRetry(error.requestOptions)) {
            final bool refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final Response<dynamic> response = await _dio.fetch(_markRetry(error.requestOptions));
                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                handler.next(retryError);
                return;
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  Dio get dio => _dio;

  bool _isRetry(RequestOptions options) => options.extra['botdynax_retried'] == true;

  RequestOptions _markRetry(RequestOptions options) {
    options.extra['botdynax_retried'] = true;
    return options;
  }

  Future<bool> _tryRefresh() async {
    final String? refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final Response<Map<String, dynamic>> response = await Dio(
        BaseOptions(baseUrl: BackendConfig.apiBaseUrl),
      ).post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refreshToken});

      final String accessToken = response.data!['accessToken'] as String;
      final String newRefreshToken = response.data!['refreshToken'] as String;
      await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }
}
