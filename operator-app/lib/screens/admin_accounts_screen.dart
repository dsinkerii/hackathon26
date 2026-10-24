import 'package:flutter/material.dart';

import '../models/admin_account.dart';
import '../services/admin_repository.dart';
import '../widgets/adaptivity.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({
    super.key,
    required this.repository,
    this.currentUsername,
  });

  final AdminRepository repository;
  final String? currentUsername;

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  late Future<List<AdminAccount>> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = widget.repository.fetchAccounts();
  }

  void _reload() => setState(() {
        _accounts = widget.repository.fetchAccounts();
      });

  Future<void> _createAccount() async {
    final input = await showDialog<_NewAccount>(
      context: context,
      builder: (_) => const _NewAccountDialog(),
    );
    if (input == null) return;
    try {
      await widget.repository.createAccount(
        username: input.username,
        password: input.password,
        role: input.role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Учётная запись создана')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _setEnabled(AdminAccount account, bool enabled) async {
    try {
      await widget.repository.setAccountEnabled(account.id, enabled);
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось выполнить действие: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Доступ и учётные записи',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text('Создание операторов и администраторов проекта'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _createAccount,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Добавить пользователя'),
            ),
            IconButton(
              onPressed: _reload,
              tooltip: 'Обновить',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<AdminAccount>>(
          future: _accounts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AdminLoadError(
                error: snapshot.error!,
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Учётных записей пока нет.'),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final account in snapshot.data!)
                    _AccountTile(
                      account: account,
                      isCurrent: account.username == widget.currentUsername,
                      onEnabledChanged: (enabled) =>
                          _setEnabled(account, enabled),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'Роли: администратор управляет камерами, записями и пользователями; '
          'оператор просматривает камеры и записи и работает с инцидентами.',
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isCurrent,
    required this.onEnabledChanged,
  });

  final AdminAccount account;
  final bool isCurrent;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(account.role == 'ADMIN'
            ? Icons.admin_panel_settings
            : Icons.person),
      ),
      title: Text('${account.username}${isCurrent ? ' (вы)' : ''}'),
      subtitle: Text(
        '${account.role == 'ADMIN' ? 'Администратор' : 'Оператор'} · '
        '${account.enabled ? 'активна' : 'отключена'}',
      ),
      trailing: Switch(
        value: account.enabled,
        onChanged: isCurrent && account.enabled ? null : onEnabledChanged,
      ),
    );
  }
}

class _NewAccount {
  const _NewAccount(this.username, this.password, this.role);
  final String username;
  final String password;
  final String role;
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'OPERATOR';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Новая учётная запись'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: adaptiveWidth(context, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _username,
                  decoration:
                      const InputDecoration(labelText: 'Имя пользователя'),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Минимум 3 символа'
                      : null,
                ),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 12
                      ? 'Не менее 12 символов'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Роль'),
                  items: const [
                    DropdownMenuItem(
                        value: 'OPERATOR', child: Text('Оператор')),
                    DropdownMenuItem(
                        value: 'ADMIN', child: Text('Администратор')),
                  ],
                  onChanged: (role) {
                    if (role != null) setState(() => _role = role);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _NewAccount(_username.text.trim(), _password.text, _role),
              );
            },
            child: const Text('Создать'),
          ),
        ],
      );
}

class _AdminLoadError extends StatelessWidget {
  const _AdminLoadError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Не удалось загрузить данные'),
          subtitle: Text(error.toString()),
          trailing:
              IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ),
      );
}
