import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/incident.dart';
import 'operator_repository.dart';

/// Shared live incident state for the whole operator shell.
///
/// WebSocket alerts arrive immediately and are merged into the list; a slower
/// REST reconciliation catches anything missed while the socket was down.
class IncidentFeed extends ChangeNotifier {
  IncidentFeed({required this.repository});

  final OperatorRepository repository;

  List<Incident> _incidents = const [];
  final Map<String, DateTime> _recentAlertIds = {};
  StreamSubscription<Incident>? _subscription;
  Timer? _reconcileTimer;
  bool _loading = true;
  bool _live = false;
  Object? _error;
  Incident? _latestAlert;
  bool _started = false;

  List<Incident> get incidents => _incidents;
  bool get loading => _loading;
  bool get live => _live;
  Object? get error => _error;
  Incident? get latestAlert => _latestAlert;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _subscription = repository.incidentAlerts().listen(
      _onAlert,
      onError: (Object error) {
        _live = false;
        notifyListeners();
      },
      onDone: () {
        _live = false;
        notifyListeners();
      },
    );
    _live = true;
    notifyListeners();
    _reconcileTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refresh(silent: true),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final fetched = await repository.fetchIncidents();
      // Keep an alert that arrived while the REST snapshot was in flight, but
      // do not resurrect incidents deleted by the operator (for example when a
      // visitor is removed together with their incidents).
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      _recentAlertIds.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
      final inFlightAlerts = _incidents
          .where((incident) => _recentAlertIds.containsKey(incident.id))
          .toList();
      _incidents = _merge(fetched, inFlightAlerts);
      _error = null;
    } catch (error) {
      if (!silent) _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onAlert(Incident incident) {
    _recentAlertIds[incident.id] = DateTime.now();
    _incidents = _merge([incident], _incidents);
    _latestAlert = incident;
    _error = null;
    _live = true;
    notifyListeners();
  }

  /// Удаляет инцидент на сервере и сразу убирает его из живого списка.
  ///
  /// Заметка в [_recentAlertIds] стирается, чтобы пришедший в пике websocket не
  /// «воскресил» запись, которую оператор только что удалил.
  Future<void> deleteIncident(String id) async {
    await repository.deleteIncident(id);
    _recentAlertIds.remove(id);
    _incidents = List.unmodifiable(
      _incidents.where((incident) => incident.id != id),
    );
    notifyListeners();
  }

  /// Server data wins for shared IDs, but a just-pushed alert is never lost if
  /// a REST snapshot was taken a moment earlier.
  List<Incident> _merge(List<Incident> primary, List<Incident> secondary) {
    final byId = <String, Incident>{
      for (final incident in secondary) incident.id: incident,
      for (final incident in primary) incident.id: incident,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(merged);
  }

  @override
  void dispose() {
    _reconcileTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
