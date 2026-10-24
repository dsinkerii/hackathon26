import 'package:flutter/material.dart';

import 'models/incident.dart';
import 'screens/incidents_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/visitors_screen.dart';
import 'services/api_operator_repository.dart';
import 'services/operator_repository.dart';

void main() {
  runApp(const SafePlaygroundApp());
}

class SafePlaygroundApp extends StatelessWidget {
  const SafePlaygroundApp({super.key, this.repository});

  final OperatorRepository? repository;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF187A5A);
    final operatorRepository =
        repository ?? ApiOperatorRepository.fromEnvironment();

    return MaterialApp(
      title: 'Безопасная площадка',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      home: OperatorShell(repository: operatorRepository),
    );
  }
}

class OperatorShell extends StatefulWidget {
  const OperatorShell({super.key, required this.repository});

  final OperatorRepository repository;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Безопасная площадка'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () => _showNotifications(context),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: switch (_selectedIndex) {
          0 => MonitoringScreen(repository: widget.repository),
          1 => IncidentsScreen(repository: widget.repository),
          _ => VisitorsScreen(repository: widget.repository),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Мониторинг',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Инциденты',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Посетители',
          ),
        ],
      ),
    );
  }

  Future<void> _showNotifications(BuildContext context) async {
    final incidents = widget.repository.fetchIncidents();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Уведомления'),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<Incident>>(
            future: incidents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Не удалось загрузить уведомления: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Новых уведомлений нет.');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: snapshot.data!
                      .take(5)
                      .map(
                        (incident) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.warning_amber_outlined),
                          title: Text(incident.type),
                          subtitle: Text(
                            incident.description ??
                                incident.occurredAt.toLocal().toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
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
}
