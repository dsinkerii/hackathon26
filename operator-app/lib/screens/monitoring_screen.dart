import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../services/operator_repository.dart';
import 'recordings_screen.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key, required this.repository});

  final OperatorRepository repository;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  late Future<List<Incident>> _latestIncidents;

  @override
  void initState() {
    super.initState();
    _latestIncidents = widget.repository.fetchIncidents();
  }

  void _refresh() {
    setState(() => _latestIncidents = widget.repository.fetchIncidents());
  }

  Future<void> _openRecordings() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const RecordingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final padding = compact ? 12.0 : 20.0;
        final videoPanel = _CameraPanel(
          compact: compact,
          onOpenRecordings: _openRecordings,
        );
        final activityPanel = _ActivityPanel(
          incidents: _latestIncidents,
          onRefresh: _refresh,
        );

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Мониторинг',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _ServiceStatus(incidents: _latestIncidents),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          Expanded(flex: 6, child: videoPanel),
                          const SizedBox(height: 10),
                          Expanded(flex: 4, child: activityPanel),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: videoPanel),
                          const SizedBox(width: 16),
                          SizedBox(width: 320, child: activityPanel),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceStatus extends StatelessWidget {
  const _ServiceStatus({required this.incidents});

  final Future<List<Incident>> incidents;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Incident>>(
      future: incidents,
      builder: (context, snapshot) {
        final connected = snapshot.hasData;
        final failed = snapshot.hasError;
        final color = connected
            ? Theme.of(context).colorScheme.primary
            : failed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondary;
        return Chip(
          avatar: Icon(
            connected
                ? Icons.cloud_done_outlined
                : failed
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_sync_outlined,
            size: 18,
            color: color,
          ),
          label: Text(
            connected
                ? 'Сервис подключён'
                : failed
                    ? 'Сервис не подключён'
                    : 'Подключение...',
          ),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.compact,
    required this.onOpenRecordings,
  });

  final bool compact;
  final VoidCallback onOpenRecordings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF17211E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white70,
                    size: 36,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Видеопоток не подключён',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onOpenRecordings,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(compact ? 'Записи' : 'Записи видео'),
          ),
        ),
      ],
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.incidents,
    required this.onRefresh,
  });

  final Future<List<Incident>> incidents;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Последние события',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Обновить',
                  icon: const Icon(Icons.refresh),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Incident>>(
                future: incidents,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'События недоступны.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final latest = snapshot.data!.take(4).toList();
                  if (latest.isEmpty) {
                    return const Center(
                      child: Text(
                        'Новых событий пока нет',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView(
                    children: latest
                        .map(
                          (incident) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading:
                                const Icon(Icons.notifications_active_outlined),
                            title: Text(
                              incident.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              incident.occurredAt.toLocal().toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
