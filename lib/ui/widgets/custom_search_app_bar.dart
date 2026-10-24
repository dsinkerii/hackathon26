import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../screens/settings_screen.dart';

class CustomSearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppState state;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  const CustomSearchAppBar({
    super.key,
    required this.state,
    this.searchController,
    this.onSearchChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Меню',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'PlayGuardAI',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Поиск',
              onPressed: () {},
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(state: state),
                    ),
                  );
                },
                child: Hero(
                  tag: 'profile_avatar',
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/avatar_02.jpg',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(
                          state.settings.userName.isNotEmpty
                              ? state.settings.userName[0].toUpperCase()
                              : 'О',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
