import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../state/app_state.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  final AppState state;

  const ChatListScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chats = state.chats.where((c) {
      if (state.searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(state.searchQuery.toLowerCase()) ||
          c.subtitle.toLowerCase().contains(state.searchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: () => state.refreshAll(),
      child: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Чатов не найдено',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 76,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _M3ChatTile(
                  key: ValueKey(chat.id),
                  chat: chat,
                  index: index,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(chat: chat, state: state),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _M3ChatTile extends StatelessWidget {
  final Chat chat;
  final int index;
  final VoidCallback onTap;

  const _M3ChatTile({
    super.key,
    required this.chat,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Smooth staggered entrance animation matching M3 standard motion (250ms with curve)
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 40).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Container
              Hero(
                tag: 'chat_avatar_${chat.id}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: chat.isGroup
                      ? colorScheme.primaryContainer
                      : colorScheme.secondaryContainer,
                  child: chat.avatarAsset != null
                      ? ClipOval(
                          child: Image.asset(
                            chat.avatarAsset!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Text(
                              chat.avatarLetter ?? 'Ч',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        )
                      : (chat.isGroup
                          ? Icon(
                              Icons.people,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            )
                          : Text(
                              chat.avatarLetter ?? 'Ч',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            )),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(chat.lastMessageTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: chat.unreadCount > 0
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: chat.unreadCount > 0
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (now.difference(dt).inDays < 7) {
      const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return weekdays[dt.weekday - 1];
    } else {
      return '${dt.day}.${dt.month}';
    }
  }
}
