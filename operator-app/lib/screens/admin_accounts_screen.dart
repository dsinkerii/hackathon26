import 'package:flutter/material.dart';

import '../models/admin_account.dart';
import '../widgets/mac_switch.dart';
import '../services/admin_repository.dart';
import '../widgets/account_profile_details.dart';
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

  /// Полное удаление учётной записи (кроме основной и собственной) —
  /// после подтверждения диалогом.
  Future<void> _deleteAccount(AdminAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(username: account.username),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteAccount(account.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Учётная запись удалена')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _openAccountProfile(AdminAccount account) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AccountProfileDialog(
        account: account,
        repository: widget.repository,
        isCurrent: account.username == widget.currentUsername,
      ),
    );
    if (mounted) _reload();
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
                      onOpenProfile: () => _openAccountProfile(account),
                      onEnabledChanged: (enabled) =>
                          _setEnabled(account, enabled),
                      onDelete: () => _deleteAccount(account),
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
    required this.onOpenProfile,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  final AdminAccount account;
  final bool isCurrent;
  final VoidCallback onOpenProfile;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onOpenProfile,
      leading: CircleAvatar(
        child: Icon(account.role == 'ADMIN'
            ? Icons.admin_panel_settings
            : Icons.person),
      ),
      title: Text('${account.username}${isCurrent ? ' (вы)' : ''}'),
      subtitle: Text(
        '${account.role == 'ADMIN' ? 'Администратор' : 'Оператор'}'
        '${account.primary ? ' · главная' : ''} · '
        '${account.enabled ? 'активна' : 'отключена'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!account.primary && !isCurrent)
            IconButton(
              tooltip: 'Удалить пользователя',
              onPressed: onDelete,
              icon: const Icon(Icons.person_remove_outlined),
              color: const Color(0xFFFF3B30),
            ),
          MacSwitch(
            value: account.enabled,
            onChanged: isCurrent && account.enabled ? null : onEnabledChanged,
          ),
        ],
      ),
    );
  }
}

/// Диалог подтверждения удаления учётной записи.
class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить учётную запись?'),
      content: SizedBox(
        width: adaptiveWidth(context, 380),
        child: Text(
          'У пользователя «$username» будет отозван доступ, учётная запись '
          'и её пароль будут удалены вместе с ней. Действие необратимо. '
          'Продолжить?',
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

/// Карточка профиля другого пользователя из раздела «Доступ».
class _AccountProfileDialog extends StatefulWidget {
  const _AccountProfileDialog({
    required this.account,
    required this.repository,
    this.isCurrent = false,
  });

  final AdminAccount account;
  final AdminRepository repository;
  final bool isCurrent;

  @override
  State<_AccountProfileDialog> createState() =>
      _AccountProfileDialogState();
}

class _AccountProfileDialogState extends State<_AccountProfileDialog> {
  late bool _enabled = widget.account.enabled;
  bool _busy = false;
  Object? _error;

  /// Отключить собственную активную учётную запись нельзя —
  /// это же правило действует и на backend.
  bool get _locked => widget.isCurrent && _enabled;

  Future<void> _toggle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.setAccountEnabled(widget.account.id, !_enabled);
      if (!mounted) return;
      setState(() => _enabled = !_enabled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final role = account.role == 'ADMIN' ? 'Администратор' : 'Оператор';
    final displayName =
        '${account.username}${widget.isCurrent ? ' (вы)' : ''}';
    return AlertDialog(
      title: const Text('Профиль'),
      content: SizedBox(
        width: adaptiveWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  child: Icon(account.role == 'ADMIN'
                      ? Icons.admin_panel_settings
                      : Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            AccountDetailRow(
                icon: Icons.alternate_email,
                label: 'Логин',
                value: account.username),
            AccountDetailRow(icon: Icons.shield_outlined, label: 'Роль', value: role),
            AccountDetailRow(
              icon: Icons.verified_user_outlined,
              label: 'Статус',
              value: _enabled ? 'Активна' : 'Отключена',
              valueColor: _enabled
                  ? const Color(0xFF248A3D)
                  : const Color(0xFFFF3B30),
            ),
            AccountDetailRow(icon: Icons.tag, label: 'ID', value: account.id),
            AccountDetailRow(
                icon: Icons.history,
                label: 'Создан',
                value: formatAccountTimestamp(account.createdAt)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Не удалось изменить статус: $_error',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFFF3B30)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!_locked)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor:
                  _enabled ? const Color(0xFFFF3B30) : const Color(0xFF248A3D),
            ),
            onPressed: _busy ? null : _toggle,
            child: Text(_busy
                ? 'Сохранение…'
                : _enabled
                    ? 'Отключить'
                    : 'Включить'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
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
