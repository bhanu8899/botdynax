import 'package:dio/dio.dart';

/// Thin client for the backend's `/tuya` account-linking endpoints. The
/// actual Tuya OAuth-style handshake (open the auth URL, capture the
/// redirect's `code`) is driven by [TuyaLinkScreen]; this class just talks
/// to our own backend.
class TuyaLinkService {
  TuyaLinkService({required this._dio});

  final Dio _dio;

  Future<String> getAuthUrl() async {
    final Response<Map<String, dynamic>> response =
        await _dio.get<Map<String, dynamic>>('/tuya/auth-url');
    return response.data!['url'] as String;
  }

  Future<void> linkAccount(String code) async {
    await _dio.post<void>('/tuya/link', data: {'code': code});
  }

  Future<void> unlinkAccount() async {
    await _dio.delete<void>('/tuya/link');
  }
}
