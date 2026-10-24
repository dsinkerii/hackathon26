import 'dart:async';
import '../models/app_settings_model.dart';
import '../models/camera_model.dart';
import '../models/chat_model.dart';
import '../models/incident_model.dart';
import 'backend_bridge.dart';

class MockChatRepository implements IChatRepository {
  final List<Chat> _chats = [
    Chat(
      id: 'chat_general',
      title: 'Общий чат',
      subtitle: 'Соседи, кто потерял собаку во дворе? Сидит у 2 подъезда',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 8)),
      unreadCount: 2,
      isGroup: true,
      avatarAsset: null,
      avatarLetter: 'Д',
      messages: [
        ChatMessage(
          id: 'm1',
          senderId: 'user_maria',
          senderName: 'Марья Петровна',
          text: 'Доброе утро всем! Не забывайте, сегодня в 19:00 собрание.',
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          isMe: false,
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'user_oleg',
          senderName: 'Олег Валерьевич',
          text: 'Кто перегородил проезд у мусорных баков?',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isMe: false,
        ),
        ChatMessage(
          id: 'm3',
          senderId: 'me',
          senderName: 'Вы',
          text: 'Там грузовик разгружает стройматериалы, скоро уедет.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
          isMe: true,
        ),
        ChatMessage(
          id: 'm4',
          senderId: 'user_sergey',
          senderName: 'Сергей И.',
          text: 'Соседи, кто потерял собаку во дворе? Сидит у 2 подъезда',
          timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
          isMe: false,
        ),
      ],
    ),
    Chat(
      id: 'chat_maria',
      title: 'Марья Петровна',
      subtitle: 'Здравствуйте, посылка у консьержа, заберите пожалуйста',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 25)),
      unreadCount: 1,
      isGroup: false,
      avatarAsset: 'assets/images/avatar_01.jpg',
      avatarLetter: 'М',
      messages: [
        ChatMessage(
          id: 'm_mp_1',
          senderId: 'user_maria',
          senderName: 'Марья Петровна',
          text: 'Здравствуйте, посылка у консьержа, заберите пожалуйста',
          timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
          isMe: false,
        ),
      ],
    ),
    Chat(
      id: 'chat_oleg',
      title: 'Олег Валерьевич',
      subtitle: 'Привет! Я освободил гостевое место, можешь парковаться',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      unreadCount: 0,
      isGroup: false,
      avatarAsset: 'assets/images/avatar_02.jpg',
      avatarLetter: 'О',
      messages: [
        ChatMessage(
          id: 'm_ov_1',
          senderId: 'me',
          senderName: 'Вы',
          text: 'Олег, привет! Место у торца еще занято?',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isMe: true,
        ),
        ChatMessage(
          id: 'm_ov_2',
          senderId: 'user_oleg',
          senderName: 'Олег Валерьевич',
          text: 'Привет! Я освободил гостевое место, можешь парковаться',
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
          isMe: false,
        ),
      ],
    ),
    Chat(
      id: 'chat_concierge',
      title: 'Консьерж (Николай)',
      subtitle: 'Входная дверь смазана, домофон работает в штатном режиме',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isGroup: false,
      avatarAsset: 'assets/images/avatar_03.jpg',
      avatarLetter: 'К',
      messages: [
        ChatMessage(
          id: 'm_cn_1',
          senderId: 'user_concierge',
          senderName: 'Николай',
          text: 'Входная дверь смазана, домофон работает в штатном режиме',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isMe: false,
        ),
      ],
    ),
  ];

  @override
  Future<List<Chat>> getChats() async {
    return List.unmodifiable(_chats);
  }

  @override
  Future<Chat?> getChatById(String chatId) async {
    try {
      return _chats.firstWhere((c) => c.id == chatId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ChatMessage> sendMessage(String chatId, String text) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) throw Exception('Чат не найден');

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: 'Вы',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      isDelivered: true,
    );

    final chat = _chats[index];
    final updatedMessages = List<ChatMessage>.from(chat.messages)..add(msg);
    _chats[index] = chat.copyWith(
      messages: updatedMessages,
      subtitle: 'Вы: $text',
      lastMessageTime: DateTime.now(),
    );

    // Simulate auto-reply for realistic feel
    _scheduleAutoReply(chatId, text);

    return msg;
  }

  void _scheduleAutoReply(String chatId, String triggerText) {
    Future.delayed(const Duration(seconds: 2), () {
      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index == -1) return;

      final chat = _chats[index];
      String replyText = 'Принято!';
      String senderName = chat.title;

      if (chat.id == 'chat_general') {
        replyText = 'Спасибо за информацию! Будем иметь в виду.';
        senderName = 'Марья Петровна';
      } else if (chat.id == 'chat_maria') {
        replyText = 'Хорошо, спасибо! Заходите вечером на чай.';
      } else if (chat.id == 'chat_oleg') {
        replyText = 'Договорились, если что на связи!';
      } else if (chat.id == 'chat_concierge') {
        replyText = 'Ваша заявка принята диспетчером.';
      }

      final replyMsg = ChatMessage(
        id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'auto_reply',
        senderName: senderName,
        text: replyText,
        timestamp: DateTime.now(),
        isMe: false,
      );

      final updated = List<ChatMessage>.from(chat.messages)..add(replyMsg);
      _chats[index] = chat.copyWith(
        messages: updated,
        subtitle: '$senderName: $replyText',
        lastMessageTime: DateTime.now(),
      );
    });
  }

  @override
  Future<void> markAsRead(String chatId) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
    }
  }
}

class MockIncidentRepository implements IIncidentRepository {
  final List<Incident> _incidents = [
    Incident(
      id: 42,
      type: IncidentType.carOnPlayground,
      occurredAt: DateTime.now().subtract(const Duration(minutes: 18)),
      description: 'Тревога! Зафиксирован въезд автомобиля на территорию детской площадки',
      snapshotUrl: 'assets/images/banner.png',
      confidence: 0.94,
      processed: false,
    ),
    Incident(
      id: 51,
      type: IncidentType.strangerDetected,
      occurredAt: DateTime.now().subtract(const Duration(minutes: 42)),
      description: 'Обнаружен незнакомый посетитель у входной группы',
      snapshotUrl: 'assets/images/avatar_03.jpg',
      confidence: 0.81,
      processed: false,
      stranger: StrangerInfo(
        id: 12,
        bestSnapshotUrl: 'assets/images/avatar_03.jpg',
        visitCount: 4,
        firstSeen: DateTime.now().subtract(const Duration(days: 4)),
        lastSeen: DateTime.now().subtract(const Duration(minutes: 42)),
      ),
    ),
    Incident(
      id: 38,
      type: IncidentType.doorOpened,
      occurredAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
      description: 'Дверь подъезда удерживалась открытой более 3 минут',
      confidence: 0.99,
      processed: true,
      processedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Incident(
      id: 33,
      type: IncidentType.deliveryArrived,
      occurredAt: DateTime.now().subtract(const Duration(hours: 4)),
      description: 'Курьер службы доставки вошел в подъезд по одноразовому коду',
      snapshotUrl: 'assets/images/avatar_01.jpg',
      confidence: 0.88,
      processed: true,
      processedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 50)),
    ),
    Incident(
      id: 29,
      type: IncidentType.motionDetected,
      occurredAt: DateTime.now().subtract(const Duration(hours: 7)),
      description: 'Движение в ночной зоне детской площадки после 23:00',
      confidence: 0.76,
      processed: true,
      processedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  @override
  Future<List<Incident>> getIncidents({IncidentType? type, bool? processed}) async {
    return _incidents.where((i) {
      if (type != null && i.type != type) return false;
      if (processed != null && i.processed != processed) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<Incident?> getIncidentById(int id) async {
    try {
      return _incidents.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Incident> acknowledgeIncident(int id) async {
    final index = _incidents.indexWhere((i) => i.id == id);
    if (index == -1) throw Exception('Инцидент не найден');

    final updated = _incidents[index].copyWith(
      processed: true,
      processedAt: DateTime.now(),
    );
    _incidents[index] = updated;
    return updated;
  }

  @override
  Future<void> approveStranger(int strangerId, String fullName) async {
    // Finds incidents with this stranger and marks them processed
    for (int i = 0; i < _incidents.length; i++) {
      if (_incidents[i].stranger?.id == strangerId) {
        _incidents[i] = _incidents[i].copyWith(
          processed: true,
          processedAt: DateTime.now(),
        );
      }
    }
  }

  @override
  Future<int> getUnprocessedCount() async {
    return _incidents.where((i) => !i.processed).length;
  }
}

class MockCameraRepository implements ICameraRepository {
  CameraFeed _porchCamera = CameraFeed(
    id: 'cam_porch_01',
    name: 'Камера Подъезда №1',
    address: 'Ул. Пушкина, дом Колотушкина',
    snapshotAsset: 'assets/images/porch_camera.png',
    streamUrl: 'http://192.168.1.10:8000/video_feed',
    isOnline: true,
    isRecording: true,
    lastPing: DateTime.now(),
    doorLocked: true,
  );

  @override
  Future<CameraFeed> getPorchCamera() async {
    return _porchCamera;
  }

  @override
  Future<bool> unlockPorchDoor({int durationSeconds = 5}) async {
    _porchCamera = _porchCamera.copyWith(doorLocked: false);
    Future.delayed(Duration(seconds: durationSeconds), () {
      _porchCamera = _porchCamera.copyWith(doorLocked: true);
    });
    return true;
  }

  @override
  Future<bool> toggleAlarm() async {
    return true;
  }
}

class MockSettingsRepository implements ISettingsRepository {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> getSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class MockBackendBridge implements IBackendBridge {
  static final MockBackendBridge _instance = MockBackendBridge._internal();
  factory MockBackendBridge() => _instance;
  MockBackendBridge._internal();

  @override
  final IChatRepository chats = MockChatRepository();

  @override
  final IIncidentRepository incidents = MockIncidentRepository();

  @override
  final ICameraRepository camera = MockCameraRepository();

  @override
  final ISettingsRepository settings = MockSettingsRepository();
}
