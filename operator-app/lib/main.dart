import 'package:flutter/material.dart';

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
}
