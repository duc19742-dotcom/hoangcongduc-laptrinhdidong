import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000',
          );

  final http.Client _client;
  final String baseUrl;
  String? _token;
  Map<String, dynamic>? user;
  bool get isAuthenticated => _token != null;

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (_token != null) 'Authorization': 'Bearer $_token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw AuthException(data['message'] as String? ?? 'Yêu cầu thất bại.');
      }
      return data;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Kết nối quá lâu. Vui lòng thử lại.');
    } catch (_) {
      throw const AuthException(
        'Không kết nối được máy chủ. Kiểm tra backend và địa chỉ API_BASE_URL.',
      );
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) =>
      _request('/auth/login', {'username': username, 'password': password});

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String phone,
    required String password,
  }) => _request('/auth/register', {
    'name': name,
    'username': username,
    'phone': phone,
    'password': password,
  });

  Future<void> verify(String challengeId, String code) async {
    final data = await _request('/auth/verify', {
      'challengeId': challengeId,
      'code': code,
    });
    _token = data['token'] as String;
    user = data['user'] as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> resend(String challengeId) async {
    await _request('/auth/resend', {'challengeId': challengeId});
  }

  Future<void> logout() async {
    try {
      await _request('/auth/logout', {});
    } finally {
      _token = null;
      user = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
