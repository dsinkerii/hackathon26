import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_playground_operator/models/camera.dart';
import 'package:safe_playground_operator/models/incident.dart';
import 'package:safe_playground_operator/models/visitor.dart';
import 'package:safe_playground_operator/services/incident_feed.dart';
import 'package:safe_playground_operator/services/operator_repository.dart';

void main() {
  test('a pushed alert appears in the feed without a refresh', () async {
    final repository = _FeedRepository();
    final feed = IncidentFeed(repository: repository);
    await feed.start();

    final alert = Incident(
      id: 'live-1',
      type: 'STRANGER_DETECTED',
      occurredAt: DateTime.utc(2026, 10, 25, 10),
      description: 'Обнаружен незнакомый посетитель',
      snapshotUrl: 'http://localhost:8086/media/snapshots/live-1.jpg',
    );
    repository.push(alert);
    await Future<void>.delayed(Duration.zero);

    expect(feed.incidents.single.id, 'live-1');
    expect(feed.latestAlert?.id, 'live-1');
    expect(feed.live, isTrue);

    feed.dispose();
    await repository.close();
  });

  test('deleteIncident removes the record from the live list', () async {
    final repository = _FeedRepository();
    final feed = IncidentFeed(repository: repository);
    await feed.start();

    final alert = Incident(
      id: 'live-2',
      type: 'CAR_IN_ZONE',
      occurredAt: DateTime.utc(2026, 10, 25, 11),
      description: 'Тревога! Автомобиль на детской площадке',
    );
    repository.push(alert);
    await Future<void>.delayed(Duration.zero);
    expect(feed.incidents.single.id, 'live-2');

    await feed.deleteIncident('live-2');

    expect(feed.incidents, isEmpty);
    expect(repository.deleted, ['live-2']);

    feed.dispose();
    await repository.close();
  });
}

class _FeedRepository implements OperatorRepository {
  final deleted = <String>[];
  final _alerts = StreamController<Incident>.broadcast();

  void push(Incident incident) => _alerts.add(incident);
  Future<void> close() => _alerts.close();

  @override
  Stream<Incident> incidentAlerts() => _alerts.stream;

  @override
  Future<List<Incident>> fetchIncidents() async => const [];

  @override
  Future<List<Camera>> fetchCameras() async => const [];

  @override
  Future<List<Visitor>> fetchVisitors() async => const [];

  @override
  Future<List<Visitor>> fetchWhitelist() async => const [];

  @override
  Future<void> confirmVisitor(String id) async {}

  @override
  Future<void> excludeVisitor(String id) async {}

  @override
  Future<void> removeVisitor(String id) async {}

  @override
  Future<void> deleteIncident(String id) async => deleted.add(id);
}
