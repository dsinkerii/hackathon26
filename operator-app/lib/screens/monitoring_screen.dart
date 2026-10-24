import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../services/operator_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _latestIncidents;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Мониторинг', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          const _CameraStatus(),
          const SizedBox(height: 20),
          Text('Камера', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _VideoPlaceholder(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Последние события',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          FutureBuilder<List<Incident>>(
            future: _latestIncidents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('События недоступны: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final incidents = snapshot.data!.take(3).toList();
              if (incidents.isEmpty) {
                return const Text('Новых событий пока нет');
              }
              return Column(
                children: incidents
                    .map(
                      (incident) => ListTile(
                        leading:
                            const Icon(Icons.notifications_active_outlined),
                        title: Text(incident.type),
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
        ],
      ),
    );
  }
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Видеосервис не подключён'),
        subtitle: Text('Поток появится после настройки CV-сервиса.'),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF17211E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 40,
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
    );
  }
}
