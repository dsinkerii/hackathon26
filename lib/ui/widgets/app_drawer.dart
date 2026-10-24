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

    final unreadChats =
        state.chats.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Drawer(
      backgroundColor: colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header in Material You styling
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(28),
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
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
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

            const SizedBox(height: 12),

            // Material 3 Navigation Items with Stadium selection
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.videocam_outlined,
                    selectedIcon: Icons.videocam,
                    title: 'Подъезд и камера',
                    isSelected: state.selectedTabIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(0);
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    title: 'Соседские чаты',
                    isSelected: state.selectedTabIndex == 1,
                    badgeCount: unreadChats,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(1);
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.list_alt_outlined,
                    selectedIcon: Icons.list_alt,
                    title: 'Журнал событий',
                    isSelected: state.selectedTabIndex == 2,
                    badgeCount: state.unprocessedIncidentsCount,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectTab(2);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    title: 'Настройки',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(state: state),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    context,
                    icon: Icons.info_outline,
                    selectedIcon: Icons.info,
                    title: 'О системе',
                    isSelected: false,
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

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required bool isSelected,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget iconWidget = Icon(
      isSelected ? selectedIcon : icon,
      color: isSelected
          ? colorScheme.onSecondaryContainer
          : colorScheme.onSurfaceVariant,
      size: 22,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: colorScheme.primary,
        textColor: colorScheme.onPrimary,
        child: iconWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        selected: isSelected,
        selectedTileColor: colorScheme.secondaryContainer,
        leading: iconWidget,
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
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
          '• Мониторинг детской площадки в реальном времени\n'
          '• Детекция автомобилей на запретной территории\n'
          '• Распознавание незнакомцев и белый список соседей\n'
          '• Умный домофон и внутридомовые чаты',
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
