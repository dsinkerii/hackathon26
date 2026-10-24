import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../services/operator_repository.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key, required this.repository});

  final OperatorRepository repository;

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  late Future<List<Incident>> _incidents;

  @override
  void initState() {
    super.initState();
    _incidents = widget.repository.fetchIncidents();
  }

  void _refresh() {
    setState(() => _incidents = widget.repository.fetchIncidents());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _incidents;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Журнал инцидентов',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Incident>>(
            future: _incidents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _LoadError(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final incidents = snapshot.data!;
              if (incidents.isEmpty) {
                return const _EmptyIncidents();
              }
              return Column(
                children: incidents
                    .map((incident) => _IncidentCard(incident: incident))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final localTime = incident.occurredAt.toLocal();
    final date =
        '${localTime.day.toString().padLeft(2, '0')}.'
        '${localTime.month.toString().padLeft(2, '0')}.'
        '${localTime.year} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.warning_amber)),
        title: Text(_incidentTitle(incident.type)),
        subtitle: Text('${incident.description ?? 'Инцидент'} · $date'),
        isThreeLine: incident.description != null,
        onTap: () => _showIncidentDetails(context, incident),
      ),
    );
  }
}

Future<void> _showIncidentDetails(
  BuildContext context,
  Incident incident,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_incidentTitle(incident.type)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(incident.description ?? 'Описание не указано'),
            const SizedBox(height: 8),
            Text(incident.occurredAt.toLocal().toString()),
            if (incident.snapshotUrl != null) ...[
              const SizedBox(height: 16),
              Image.network(
                incident.snapshotUrl!,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('Не удалось загрузить снимок события.'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

String _incidentTitle(String type) {
  return switch (type.toUpperCase()) {
    'CAR_IN_ZONE' || 'VEHICLE' || 'VEHICLE_IN_ZONE' => 'Машина в зоне',
    'STRANGER' || 'UNKNOWN_PERSON' => 'Незнакомый посетитель',
    _ => type,
  };
}

class _EmptyIncidents extends StatelessWidget {
  const _EmptyIncidents();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('Инцидентов пока нет')),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off),
        title: const Text('Не удалось загрузить данные'),
        subtitle: Text(message),
        trailing: IconButton(
          onPressed: onRetry,
          tooltip: 'Повторить',
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
