import 'package:flutter/material.dart';

import '../models/visitor.dart';
import '../services/auth_service.dart';
import '../services/operator_repository.dart';
import '../widgets/adaptivity.dart';

/// Белый список посетителей: подтверждённые лица (`status=TRUSTED`)
/// с фотографией; любого из них можно удалить из списка.
class WhitelistScreen extends StatefulWidget {
  const WhitelistScreen({super.key, required this.repository});

  final OperatorRepository repository;

  @override
  State<WhitelistScreen> createState() => _WhitelistScreenState();
}

class _WhitelistScreenState extends State<WhitelistScreen> {
  late Future<List<Visitor>> _whitelist;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _whitelist = widget.repository.fetchWhitelist();
  }

  void _refresh() {
    setState(() {
      _whitelist = widget.repository.fetchWhitelist();
    });
  }

  /// Исключение из белого списка: посетитель остаётся в системе и
  /// возвращается в статус «на рассмотрении» (в разделе «Посетители»).
  Future<void> _exclude(Visitor visitor) async {
    setState(() => _busy.add(visitor.id));
    try {
      await widget.repository.excludeVisitor(visitor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Посетитель исключён из белого списка')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Не удалось исключить посетителя: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(visitor.id));
    }
  }

  /// Полное удаление посетителя вместе с фото и связанными событиями.
  Future<void> _delete(Visitor visitor) async {
    final displayName = visitor.displayName ?? 'Посетитель ${visitor.id}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteWhitelistDialog(displayName: displayName),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(visitor.id));
    try {
      await widget.repository.removeVisitor(visitor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Посетитель удалён')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить посетителя: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(visitor.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _whitelist;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Белый список', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          FutureBuilder<List<Visitor>>(
            future: _whitelist,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _WhitelistError(
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
                    child: Center(
                      child: Text(
                          'В белом списке пока никого нет. Подтвердите '
                          'посетителя в разделе «Посетители».'),
                    ),
                  ),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (visitor) => _WhitelistCard(
                        visitor: visitor,
                        isBusy: _busy.contains(visitor.id),
                        onExclude: () => _exclude(visitor),
                        onDelete: () => _delete(visitor),
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

class _WhitelistCard extends StatelessWidget {
  const _WhitelistCard({
    required this.visitor,
    required this.isBusy,
    required this.onExclude,
    required this.onDelete,
  });

  final Visitor visitor;
  final bool isBusy;
  final VoidCallback onExclude;
  final VoidCallback onDelete;

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
              leading: ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _VisitorPhoto(url: visitor.photoUrl),
                ),
              ),
              title: Text(displayName),
              subtitle: Text(
                'Посещений: ${visitor.visitCount} · '
                'Впервые: ${seenDate.day.toString().padLeft(2, '0')}.'
                '${seenDate.month.toString().padLeft(2, '0')}.'
                '${seenDate.year}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Исключить из белого списка',
                    icon: const Icon(Icons.person_remove_outlined),
                    color: const Color(0xFF6E6E73),
                    onPressed: isBusy ? null : onExclude,
                  ),
                  IconButton(
                    tooltip: 'Удалить навсегда',
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    color: const Color(0xFFFF3B30),
                    onPressed: isBusy ? null : onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Фото посетителя с авторизацией через заголовок `Authorization`;
/// при ошибке загрузки или отсутствии фото показывается заглушка.
class _VisitorPhoto extends StatelessWidget {
  const _VisitorPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final headers = AuthService.activeAccessToken == null
        ? null
        : {
            'Authorization': 'Bearer ${AuthService.activeAccessToken}',
          };
    if (url == null) {
      return ColoredBox(
        color: const Color(0xFFE5E5EA),
        child: Center(
          child: Icon(Icons.person_outline,
              size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      headers: headers,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFE5E5EA),
        child: Icon(Icons.person_outline, size: 22),
      ),
    );
  }
}

class _DeleteWhitelistDialog extends StatelessWidget {
  const _DeleteWhitelistDialog({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить навсегда'),
      content: SizedBox(
        width: adaptiveWidth(context, 380),
        child: Text(
          'Посетитель «$displayName» будет удалён вместе с его фото и '
          'связанными событиями. Действие необратимо. Продолжить?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF3B30),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    );
  }
}

class _WhitelistError extends StatelessWidget {
  const _WhitelistError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off),
        title: const Text('Не удалось загрузить белый список'),
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
