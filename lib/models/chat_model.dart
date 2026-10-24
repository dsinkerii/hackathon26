class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isDelivered;
  final String? attachmentUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isDelivered = true,
    this.attachmentUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'isDelivered': isDelivered,
      'attachmentUrl': attachmentUrl,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMe: json['isMe'] as bool? ?? false,
      isDelivered: json['isDelivered'] as bool? ?? true,
      attachmentUrl: json['attachmentUrl'] as String?,
    );
  }
}

class Chat {
  final String id;
  final String title;
  final String subtitle;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final String? avatarAsset;
  final String? avatarLetter;
  final List<ChatMessage> messages;

  const Chat({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.avatarAsset,
    this.avatarLetter,
    this.messages = const [],
  });

  Chat copyWith({
    String? title,
    String? subtitle,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isGroup,
    String? avatarAsset,
    String? avatarLetter,
    List<ChatMessage>? messages,
  }) {
    return Chat(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      avatarLetter: avatarLetter ?? this.avatarLetter,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'avatarAsset': avatarAsset,
      'avatarLetter': avatarLetter,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      isGroup: json['isGroup'] as bool? ?? false,
      avatarAsset: json['avatarAsset'] as String?,
      avatarLetter: json['avatarLetter'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
