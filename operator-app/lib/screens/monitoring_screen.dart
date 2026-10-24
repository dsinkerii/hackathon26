import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../services/operator_repository.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({
    super.key,
    required this.repository,
    this.onOpenRecordings,
  });

  final OperatorRepository repository;
  final VoidCallback? onOpenRecordings;

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
    setState(() {
      _latestIncidents = widget.repository.fetchIncidents();
    });
  }

  Future<void> _openRecordings() {
    if (widget.onOpenRecordings case final callback?) {
      callback();
      return Future<void>.value();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Раздел архива доступен после подключения API.')),
    );
    return Future<void>.value();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Мониторинг',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Состояние камер и последние события',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF6E6E73),
                                  ),
                        ),
                      ],
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
          backgroundColor:
              connected ? const Color(0xFFE7F7ED) : const Color(0xFFF5F5F7),
          side: BorderSide.none,
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF25252A), Color(0xFF111114)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 18,
                  left: 18,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_outlined,
                            size: 15, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(
                          'ОБЗОР КАМЕР',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x1FFFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Icon(
                            Icons.videocam_off_outlined,
                            color: Colors.white70,
                            size: 34,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Видеопоток не подключён',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Добавьте камеру, чтобы начать мониторинг',
                        style:
                            TextStyle(color: Color(0xFFB7B7BC), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Последние события',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Активность системы',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
