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
                  Icon(Icons.chat_bubble_outline,
                      size: 48, color: colorScheme.onSurfaceVariant),
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
                indent: 72,
                endIndent: 16,
                color: colorScheme.outlineVariant.withOpacity(0.4),
              ),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _buildChatTile(context, chat);
              },
            ),
    );
  }

  Widget _buildChatTile(BuildContext context, Chat chat) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(chat: chat, state: state),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Container matching Penpot
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
                          errorBuilder: (_, __, ___) => Text(
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
                            Icons.forum_outlined,
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

            // Content matching Penpot
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
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Support Text (Time) matching Penpot
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: chat.unreadCount > 0
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.bold
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
                                ? FontWeight.w600
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
