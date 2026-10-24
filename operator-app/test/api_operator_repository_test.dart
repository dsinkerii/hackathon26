import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:safe_playground_operator/services/api_operator_repository.dart';

void main() {
  test('loads incidents from the documented endpoint', () async {
    final client = _FakeHttpClient((request) async {
      expect(request.url.path, '/api/v1/incidents');
      return http.Response(
        jsonEncode([
          {
            'id': 'incident-1',
            'type': 'VEHICLE_IN_ZONE',
            'occurredAt': '2026-10-24T10:00:00Z',
            'description': 'Car in restricted area',
          },
        ]),
        200,
      );
    });
    final repository = ApiOperatorRepository(
      baseUri: Uri.parse('http://localhost:8080'),
      client: client,
    );

    final incidents = await repository.fetchIncidents();

    expect(incidents, hasLength(1));
    expect(incidents.single.id, 'incident-1');
  });

  test('reports non-success API responses', () async {
    final repository = ApiOperatorRepository(
      baseUri: Uri.parse('http://localhost:8080'),
      client: _FakeHttpClient(
        (_) async => http.Response('unavailable', 503),
      ),
    );

    await expectLater(
      repository.fetchVisitors(),
      throwsA(isA<ApiException>()),
    );
  });

  test('confirms a visitor using the confirm endpoint', () async {
    final client = _FakeHttpClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://localhost:8080/api/v1/persons/id%2Fwith%20space/confirm',
      );
      return http.Response('', 204);
    });
    final repository = ApiOperatorRepository(
      baseUri: Uri.parse('http://localhost:8080'),
      client: client,
    );

    await repository.confirmVisitor('id/with space');
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
