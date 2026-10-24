import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  final AppState state;
  final Function(int) onSelectTab;

  const AppDrawer({
    super.key,
    required this.state,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primaryContainer,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/avatar_02.jpg',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.person,
                              color: colorScheme.onPrimaryContainer,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.settings.userName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              state.settings.apartment,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.settings.address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: const Text('Подъезд и камера'),
                    selected: state.selectedTabIndex == 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(0);
                    },
                  ),
                  ListTile(
                    leading: Badge(
                      isLabelVisible: state.chats.any((c) => c.unreadCount > 0),
                      label: Text(
                        '${state.chats.fold<int>(0, (sum, c) => sum + c.unreadCount)}',
                      ),
                      backgroundColor: colorScheme.primary,
                      textColor: colorScheme.onPrimary,
                      child: const Icon(Icons.chat_bubble_outline),
                    ),
                    title: const Text('Соседские чаты'),
                    selected: state.selectedTabIndex == 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                  ListTile(
                    leading: Badge(
                      isLabelVisible: state.unprocessedIncidentsCount > 0,
                      label: Text('${state.unprocessedIncidentsCount}'),
                      backgroundColor: colorScheme.primary,
                      textColor: colorScheme.onPrimary,
                      child: const Icon(Icons.history_outlined),
                    ),
                    title: const Text('Журнал событий'),
                    selected: state.selectedTabIndex == 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(2);
                    },
                  ),
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Настройки'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(state: state),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('О системе'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PlayGuardAI'),
        content: const Text(
          'Интеллектуальная система безопасности двора и подъезда.\n\n'
          '- Мониторинг детской площадки в реальном времени\n'
          '- Детекция автомобилей на запретной территории\n'
          '- Распознавание незнакомцев и белый список соседей\n'
          '- Умный домофон и внутридомовые чаты',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
