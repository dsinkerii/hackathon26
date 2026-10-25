import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int unreadChats;
  final int unreadLogs;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.unreadChats,
    required this.unreadLogs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 6,
        bottom: systemBottom > 0 ? systemBottom + 8 : 16,
      ),
      child: Material(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  context,
                  index: 0,
                  label: 'Подъезд',
                  icon: Icons.videocam_outlined,
                  activeIcon: Icons.videocam,
                  badgeCount: 0,
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  context,
                  index: 1,
                  label: 'Чат',
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  badgeCount: unreadChats,
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  context,
                  index: 2,
                  label: 'Активность',
                  icon: Icons.list_alt_outlined,
                  activeIcon: Icons.list_alt,
                  badgeCount: unreadLogs,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required int badgeCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = selectedIndex == index;

    final itemColor =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    Widget iconWidget = Icon(
      isActive ? activeIcon : icon,
      size: 24,
      color: itemColor,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: colorScheme.primary,
        textColor: colorScheme.onPrimary,
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: iconWidget,
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: itemColor,
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 3),
            // Sleek active indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isActive ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
