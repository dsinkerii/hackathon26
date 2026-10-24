import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/incident.dart';
import '../models/visitor.dart';
import 'operator_repository.dart';

class ApiOperatorRepository implements OperatorRepository {
  ApiOperatorRepository({
    required Uri baseUri,
    http.Client? client,
  })  : _baseUri = baseUri,
        _client = client ?? http.Client();

  factory ApiOperatorRepository.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    );
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasAuthority || !uri.hasScheme) {
      throw ArgumentError.value(
        baseUrl,
        'API_BASE_URL',
        'Must be an absolute URL',
      );
    }
    return ApiOperatorRepository(baseUri: uri);
  }

  final Uri _baseUri;
  final http.Client _client;

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
  Future<void> confirmVisitor(String id) async {
    final response = await _client.post(
      _baseUri.resolve('/api/v1/persons/${Uri.encodeComponent(id)}/confirm'),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Не удалось добавить посетителя в белый список '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  Future<Object?> _getJson(String path) async {
    final response = await _client.get(
      _baseUri.resolve(path),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Сервер ответил с кодом HTTP ${response.statusCode}.');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Сервер вернул некорректный JSON.');
    }
  }

  String? _resolveMediaUrl(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Expected a media URL');
    }
    return _baseUri.resolve(value).toString();
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
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
