import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_session.dart';

class AuthService {
  AuthService({required Uri baseUri, http.Client? client})
      : _baseUri = baseUri,
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;
  static const _sessionKey = 'safe_playground_admin_session';
  static String? _activeAccessToken;

  static String? get activeAccessToken => _activeAccessToken;

  Future<AdminSession?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_sessionKey);
    if (saved == null) return null;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid session');
      }
      final session = AdminSession.fromJson(decoded);
      if (!session.expiresAt.isAfter(DateTime.now())) {
        _activeAccessToken = null;
        await preferences.remove(_sessionKey);
        return null;
      }
      _activeAccessToken = session.accessToken;
      return session;
    } on FormatException {
      _activeAccessToken = null;
      await preferences.remove(_sessionKey);
      return null;
    }
  }

  Future<AdminSession> login(String username, String password) async {
    final response = await _client
        .post(
          _baseUri.resolve('/api/v1/auth/login'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        final code = _errorCode(response);
        if (code == 'ACCOUNT_DISABLED') {
          throw const AuthException(
              'Учётная запись отключена администратором.');
        }
        throw const AuthException('Неверное имя пользователя или пароль.');
      }
      throw AuthException(
          'Ошибка сервера авторизации (HTTP ${response.statusCode}).');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const AuthException('Сервер вернул некорректный ответ.');
    }
    final session = AdminSession.fromJson(json);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(json));
    _activeAccessToken = session.accessToken;
    return session;
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
    _activeAccessToken = null;
  }

  static String? _errorCode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } on FormatException {
      // Response body is not JSON; treat as a generic failure.
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
