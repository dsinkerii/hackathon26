import 'package:flutter/material.dart';

import '../models/visitor.dart';
import '../services/auth_service.dart';
import '../services/operator_repository.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key, required this.repository});

  final OperatorRepository repository;

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  late Future<List<Visitor>> _visitors;
  final Set<String> _confirming = {};

  @override
  void initState() {
    super.initState();
    _visitors = widget.repository.fetchVisitors();
  }

  void _refresh() {
    setState(() {
      _visitors = widget.repository.fetchVisitors();
    });
  }

  Future<void> _confirm(Visitor visitor) async {
    setState(() => _confirming.add(visitor.id));
    try {
      await widget.repository.confirmVisitor(visitor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Посетитель добавлен в белый список')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подтвердить посетителя: $error')),
      );
    } finally {
      if (mounted) setState(() => _confirming.remove(visitor.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _visitors;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Посетители', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          FutureBuilder<List<Visitor>>(
            future: _visitors,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _VisitorError(
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
              if (snapshot.data!.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: Text('Новых посетителей пока нет')),
                  ),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (visitor) => _VisitorCard(
                        visitor: visitor,
                        isConfirming: _confirming.contains(visitor.id),
                        onConfirm:
                            visitor.isPending ? () => _confirm(visitor) : null,
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

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({
    required this.visitor,
    required this.isConfirming,
    required this.onConfirm,
  });

  final Visitor visitor;
  final bool isConfirming;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final displayName = visitor.displayName ?? 'Посетитель ${visitor.id}';
    final seenDate = visitor.firstSeenAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: visitor.photoUrl == null
                    ? null
                    : NetworkImage(
                        visitor.photoUrl!,
                        headers: AuthService.activeAccessToken == null
                            ? null
                            : {
                                'Authorization':
                                    'Bearer ${AuthService.activeAccessToken}',
                              },
                      ),
                child: visitor.photoUrl == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(displayName),
              subtitle: Text(
                'Посещений: ${visitor.visitCount} · '
                'Впервые: ${seenDate.day.toString().padLeft(2, '0')}.'
                '${seenDate.month.toString().padLeft(2, '0')}.'
                '${seenDate.year}',
              ),
            ),
            if (onConfirm != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: isConfirming ? null : onConfirm,
                  icon: isConfirming
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: const Text('Добавить в белый список'),
                ),
              )
            else
              const Chip(
                avatar: Icon(Icons.verified_outlined, size: 18),
                label: Text('В белом списке'),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitorError extends StatelessWidget {
  const _VisitorError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off),
        title: const Text('Не удалось загрузить посетителей'),
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
