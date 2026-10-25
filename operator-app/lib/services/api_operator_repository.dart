import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/admin_account.dart';
import '../models/camera.dart';
import '../models/incident.dart';
import '../models/video_recording.dart';
import '../models/visitor.dart';
import 'admin_repository.dart';
import 'operator_repository.dart';

class ApiOperatorRepository implements OperatorRepository, AdminRepository {
  ApiOperatorRepository({
    required Uri baseUri,
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  })  : _baseUri = baseUri,
        _client = client ?? http.Client(),
        _tokenProvider = tokenProvider;

  factory ApiOperatorRepository.fromEnvironment({
    Future<String?> Function()? tokenProvider,
  }) =>
      ApiOperatorRepository(
        baseUri: baseUriFromEnvironment(),
        tokenProvider: tokenProvider,
      );

  static Uri baseUriFromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8086',
    );
    // `/` means "same origin as this page". The containerised web build is
    // served by nginx, which proxies /api and /media to the backend, so the
    // app keeps working from any host or LAN address without rebuilding.
    if (baseUrl.isEmpty || baseUrl == '/') {
      return Uri.base.resolve('/');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasAuthority || !uri.hasScheme) {
      throw ArgumentError.value(
        baseUrl,
        'API_BASE_URL',
        'Must be an absolute URL',
      );
    }
    return uri;
  }

  final Uri _baseUri;
  final http.Client _client;
  final Future<String?> Function()? _tokenProvider;

  @override
  Future<List<Incident>> fetchIncidents() async {
    final json = await _getJson('/api/v1/incidents');
    return _parseList(
      json,
      (item) => Incident.fromJson({
        ...item,
        'snapshotUrl': _resolveMediaUrl(item['snapshotUrl']),
      }),
    );
  }

  @override
  Future<void> deleteIncident(String id) => _expectSuccess(
        _request('DELETE', '/api/v1/incidents/${Uri.encodeComponent(id)}'),
        'Не удалось удалить инцидент',
      );

  @override
  Stream<Incident> incidentAlerts() async* {
    if (_tokenProvider == null) {
      // Without a token provider this repository is only used by tests or
      // read-only callers; polling via fetchIncidents remains available.
      return;
    }
    var reconnectDelay = const Duration(seconds: 2);
    while (true) {
      final token = await _tokenProvider();
      if (token == null || token.isEmpty) {
        await Future<void>.delayed(reconnectDelay);
        continue;
      }

      WebSocketChannel? channel;
      try {
        channel = WebSocketChannel.connect(_alertWebSocketUri(token));
        await channel.ready;
        reconnectDelay = const Duration(seconds: 2);
        await for (final message in channel.stream) {
          if (message is! String) continue;
          try {
            final decoded = jsonDecode(message);
            if (decoded is! Map<String, dynamic>) continue;
            yield Incident.fromJson({
              ...decoded,
              'snapshotUrl': _resolveMediaUrl(decoded['snapshotUrl']),
            });
          } catch (_) {
            // Ignore one malformed alert instead of dropping the socket.
          }
        }
      } catch (_) {
        // The backend may be restarting or the token may have expired. The
        // feed also polls periodically, so a short gap is not fatal.
      } finally {
        try {
          await channel?.sink.close();
        } catch (_) {
          // The remote side may already have closed the socket.
        }
      }

      await Future<void>.delayed(reconnectDelay);
      final nextSeconds = reconnectDelay.inSeconds * 2;
      reconnectDelay = Duration(seconds: nextSeconds > 15 ? 15 : nextSeconds);
    }
  }

  Uri _alertWebSocketUri(String token) {
    final scheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    return _baseUri.replace(
      scheme: scheme,
      path: '/ws/alerts',
      queryParameters: {'token': token},
    );
  }

  @override
  Future<List<Visitor>> fetchVisitors() async {
    final json = await _getJson('/api/v1/persons');
    return _parseList(
      json,
      (item) => Visitor.fromJson({
        ...item,
        'photoUrl': _resolveMediaUrl(item['photoUrl']),
      }),
    );
  }

  @override
  Future<void> confirmVisitor(String id) => _expectSuccess(
        _request('POST', '/api/v1/persons/${Uri.encodeComponent(id)}/confirm'),
        'Не удалось добавить посетителя в белый список',
      );

  @override
  Future<void> excludeVisitor(String id) => _expectSuccess(
        _request('POST', '/api/v1/persons/${Uri.encodeComponent(id)}/revoke'),
        'Не удалось исключить посетителя из белого списка',
      );

  @override
  Future<List<Visitor>> fetchWhitelist() async {
    final json = await _getJson(
      '/api/v1/persons',
      query: const {'status': 'TRUSTED'},
    );
    return _parseList(
      json,
      (item) => Visitor.fromJson({
        ...item,
        'photoUrl': _resolveMediaUrl(item['photoUrl']),
      }),
    );
  }

  @override
  Future<void> removeVisitor(String id) => _expectSuccess(
        _request('DELETE', '/api/v1/persons/${Uri.encodeComponent(id)}'),
        'Не удалось удалить посетителя из белого списка',
      );

  @override
  Future<List<Camera>> fetchCameras() async =>
      _parseList(await _getJson('/api/v1/cameras'), Camera.fromJson);

  @override
  Future<Camera> createCamera({
    required String name,
    String? location,
    String? streamUrl,
  }) async =>
      Camera.fromJson(await _getObject(
        'POST',
        '/api/v1/cameras',
        body: {'name': name, 'location': location, 'streamUrl': streamUrl},
      ));

  @override
  Future<Camera> updateCamera(
    String id, {
    required String name,
    String? location,
    String? streamUrl,
    required bool enabled,
  }) async =>
      Camera.fromJson(await _getObject(
        'PUT',
        '/api/v1/cameras/${Uri.encodeComponent(id)}',
        body: {
          'name': name,
          'location': location,
          'streamUrl': streamUrl,
          'enabled': enabled,
        },
      ));

  @override
  Future<void> deleteCamera(String id) => _expectSuccess(
        _request('DELETE', '/api/v1/cameras/${Uri.encodeComponent(id)}'),
        'Не удалось удалить камеру',
      );

  @override
  Future<List<VideoRecording>> fetchRecordings({
    String? cameraId,
    bool? withoutCamera,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{};
    if (cameraId != null) query['cameraId'] = cameraId;
    if (withoutCamera != null && withoutCamera) {
      query['withoutCamera'] = 'true';
    }
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    return _parseList(
      await _getJson('/api/v1/recordings', query: query),
      VideoRecording.fromJson,
    );
  }

  @override
  Future<VideoRecording> createRecording({
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  }) async =>
      VideoRecording.fromJson(await _getObject(
        'POST',
        '/api/v1/recordings',
        body: _recordingBody(
          cameraId,
          title,
          eventType,
          recordedAt,
          durationSeconds,
          videoUrl,
        ),
      ));

  @override
  Future<VideoRecording> updateRecording(
    String id, {
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  }) async =>
      VideoRecording.fromJson(await _getObject(
        'PUT',
        '/api/v1/recordings/${Uri.encodeComponent(id)}',
        body: _recordingBody(
          cameraId,
          title,
          eventType,
          recordedAt,
          durationSeconds,
          videoUrl,
        ),
      ));

  Map<String, Object?> _recordingBody(
    String? cameraId,
    String title,
    String? eventType,
    DateTime recordedAt,
    int? durationSeconds,
    String videoUrl,
  ) =>
      {
        'cameraId': cameraId,
        'title': title,
        'eventType': eventType,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'videoUrl': videoUrl,
      };

  @override
  Future<void> deleteRecording(String id) => _expectSuccess(
        _request('DELETE', '/api/v1/recordings/${Uri.encodeComponent(id)}'),
        'Не удалось удалить запись',
      );

  @override
  Future<List<AdminAccount>> fetchAccounts() async =>
      _parseList(await _getJson('/api/v1/users'), AdminAccount.fromJson);

  @override
  Future<AdminAccount> fetchProfile() async =>
      AdminAccount.fromJson(await _getObject('GET', '/api/v1/auth/me'));

  @override
  Future<AdminAccount> createAccount({
    required String username,
    required String password,
    required String role,
  }) async =>
      AdminAccount.fromJson(await _getObject(
        'POST',
        '/api/v1/users',
        body: {'username': username, 'password': password, 'role': role},
      ));

  @override
  Future<AdminAccount> setAccountEnabled(String id, bool enabled) async =>
      AdminAccount.fromJson(await _getObject(
        'PATCH',
        '/api/v1/users/${Uri.encodeComponent(id)}/enabled',
        body: {'enabled': enabled},
      ));

  @override
  Future<void> deleteAccount(String id) => _expectSuccess(
        _request('DELETE', '/api/v1/users/${Uri.encodeComponent(id)}'),
        'Не удалось удалить учётную запись',
      );

  Future<Object?> _getJson(String path, {Map<String, String>? query}) async {
    final response = await _request('GET', path, query: query);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiError(response);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Сервер вернул некорректный JSON.');
    }
  }

  Future<Map<String, dynamic>> _getObject(
    String method,
    String path, {
    Object? body,
  }) async {
    final response = await _request(method, path, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiError(response);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Ожидался JSON-объект от сервера.');
    }
    return decoded;
  }

  Future<void> _expectSuccess(
    Future<http.Response> responseFuture,
    String errorPrefix,
  ) async {
    final response = await responseFuture;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('$errorPrefix: ${_apiError(response)}');
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final token = await _tokenProvider?.call();
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final encodedBody = body == null ? null : jsonEncode(body);
    final request = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ =>
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method'),
    };
    return request.timeout(const Duration(seconds: 10));
  }

  ApiException _apiError(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return ApiException(decoded['message'] as String);
      }
    } on FormatException {
      // Use the HTTP status when the server response is not JSON.
    }
    return ApiException('Сервер ответил с кодом HTTP ${response.statusCode}.');
  }

  List<T> _parseList<T>(
    Object? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json is! List) {
      throw const ApiException('Ожидался JSON-массив от сервера.');
    }
    try {
      return json.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Expected an object');
        }
        return fromJson(item);
      }).toList();
    } on FormatException catch (error) {
      throw ApiException('Некорректные данные от сервера: ${error.message}.');
    }
  }

  String? _resolveMediaUrl(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Expected a media URL');
    }
    return _baseUri.resolve(value).toString();
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
