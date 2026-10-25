import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../services/incident_feed.dart';
import '../services/operator_repository.dart';
import '../widgets/authenticated_image.dart';
import '../widgets/incident_thumbnail.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({
    super.key,
    required this.repository,
    required this.feed,
  });

  final OperatorRepository repository;
  final IncidentFeed feed;

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  Future<void> _refresh() => widget.feed.refresh();

  Future<void> _deleteIncident(Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить инцидент?'),
        content: Text(
          'Запись «${_incidentTitle(incident.type)}» будет удалена '
          'из журнала безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB00020),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.feed.deleteIncident(incident.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Инцидент удалён')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить инцидент: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Журнал инцидентов',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              AnimatedBuilder(
                animation: widget.feed,
                builder: (context, _) => _LiveBadge(
                  live: widget.feed.live,
                  count: widget.feed.incidents.length,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: widget.feed,
            builder: (context, _) {
              if (widget.feed.error != null &&
                  widget.feed.incidents.isEmpty) {
                return _LoadError(
                  message: widget.feed.error.toString(),
                  onRetry: _refresh,
                );
              }
              if (widget.feed.loading && widget.feed.incidents.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final incidents = widget.feed.incidents;
              if (incidents.isEmpty) {
                return const _EmptyIncidents();
              }
              return Column(
                children: incidents
                    .map((incident) => _IncidentCard(
                          incident: incident,
                          onDelete: () => _deleteIncident(incident),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.live, required this.count});

  final bool live;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          live ? Icons.fiber_manual_record : Icons.wifi_tethering_off_outlined,
          size: 12,
          color: live ? const Color(0xFFB00020) : const Color(0xFF8E8E93),
        ),
        const SizedBox(width: 5),
        Text(
          live ? 'LIVE · $count' : 'ОЖИДАНИЕ · $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: live ? const Color(0xFFB00020) : const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onDelete});

  final Incident incident;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localTime = incident.occurredAt.toLocal();
    final date = '${localTime.day.toString().padLeft(2, '0')}.'
        '${localTime.month.toString().padLeft(2, '0')}.'
        '${localTime.year} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    final isPerson = incident.type.toUpperCase() == 'STRANGER_DETECTED';
    return Card(
      child: ListTile(
        leading: IncidentThumbnail(url: incident.snapshotUrl, size: 58),
        title: Text(_incidentTitle(incident.type)),
        subtitle: Text('${incident.description ?? 'Инцидент'} · $date'),
        isThreeLine: incident.description != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isPerson
                  ? const Color(0xFFEAF2FF)
                  : const Color(0xFFFFECEC),
              child: Icon(
                isPerson ? Icons.person_outline : Icons.directions_car_outlined,
                size: 18,
                color: isPerson ? const Color(0xFF2F6FED) : const Color(0xFFB00020),
              ),
            ),
            IconButton(
              tooltip: 'Удалить инцидент',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: const Color(0xFFB00020),
              onPressed: onDelete,
            ),
          ],
        ),
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
              SizedBox(
                width: double.infinity,
                height: 260,
                child: AuthenticatedImage(
                  url: incident.snapshotUrl!,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: Text('Загрузка снимка события...'),
                  ),
                  errorWidget: const Center(
                    child: Text('Не удалось загрузить снимок события.'),
                  ),
                ),
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
    'CAR_IN_ZONE' || 'VEHICLE' || 'VEHICLE_IN_ZONE' => 'Автомобиль в зоне',
    'STRANGER' || 'UNKNOWN_PERSON' || 'STRANGER_DETECTED' =>
      'Незнакомый посетитель',
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
