import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../screens/settings_screen.dart';

class CustomSearchAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  State<CustomSearchAppBar> createState() => _CustomSearchAppBarState();
}

class _CustomSearchAppBarState extends State<CustomSearchAppBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.searchController?.text.isNotEmpty ?? false;
    widget.searchController?.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.searchController?.text.isNotEmpty ?? false;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Меню',
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  onChanged: widget.onSearchChanged,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'PlayGuardAI',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: _hasText
                    ? IconButton(
                        key: const ValueKey('clear_btn'),
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Очистить',
                        onPressed: () {
                          widget.searchController?.clear();
                          widget.onSearchChanged?.call('');
                        },
                      )
                    : IconButton(
                        key: const ValueKey('search_btn'),
                        icon: const Icon(Icons.search),
                        tooltip: 'Поиск',
                        onPressed: () {},
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, left: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(state: widget.state),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_avatar',
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: colorScheme.primaryContainer,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/avatar_02.jpg',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            widget.state.settings.userName.isNotEmpty
                                ? widget.state.settings.userName[0].toUpperCase()
                                : 'О',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
      ),
    );
  }
}
