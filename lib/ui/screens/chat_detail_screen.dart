import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import '../../state/app_state.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  final AppState state;

  const ChatDetailScreen({
    super.key,
    required this.chat,
    required this.state,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.state.markChatAsRead(widget.chat.id);
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final canSend = _textController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.state.sendMessage(widget.chat.id, text);
    _textController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chat = widget.state.chats.firstWhere(
      (c) => c.id == widget.chat.id,
      orElse: () => widget.chat,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        scrolledUnderElevation: 3,
        title: Row(
          children: [
            Hero(
              tag: 'chat_avatar_${chat.id}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                child: chat.avatarAsset != null
                    ? ClipOval(
                        child: Image.asset(
                          chat.avatarAsset!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Text(chat.avatarLetter ?? 'Ч'),
                        ),
                      )
                    : (chat.isGroup
                        ? Icon(
                            Icons.people,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          )
                        : Text(chat.avatarLetter ?? 'Ч')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    chat.isGroup ? '34 соседа в сети' : 'онлайн',
                    style: TextStyle(
                      fontSize: 12,
                      color: chat.isGroup
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Позвонить',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Аудиовызов через домофонную сеть')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Опции',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                final msg = chat.messages[index];
                return _buildMessageBubble(context, msg);
              },
            ),
          ),

          // Message Input Field in Material You style
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded),
                    tooltip: 'Прикрепить',
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Прикрепление медиафайлов'),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Сообщение соседям...',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _canSend ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: _canSend ? _sendMessage : null,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _canSend ? Icons.send_rounded : Icons.mic_rounded,
                          key: ValueKey<bool>(_canSend),
                          size: 20,
                        ),
                      ),
                      tooltip: _canSend ? 'Отправить' : 'Голосовое сообщение',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage msg) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMe = msg.isMe;

    final bubbleBg = isMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final textColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.secondaryContainer,
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && widget.chat.isGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.65),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
