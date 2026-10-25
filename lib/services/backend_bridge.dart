import '../models/app_settings_model.dart';
import '../models/camera_model.dart';
import '../models/chat_model.dart';
import '../models/incident_model.dart';

abstract class IChatRepository {
  Future<List<Chat>> getChats();
  Future<Chat?> getChatById(String chatId);
  Future<ChatMessage> sendMessage(String chatId, String text);
  Future<void> markAsRead(String chatId);
}

abstract class IIncidentRepository {
  Future<List<Incident>> getIncidents({IncidentType? type, bool? processed});
  Future<Incident?> getIncidentById(int id);
  Future<Incident> acknowledgeIncident(int id);
  Future<void> approveStranger(int strangerId, String fullName);
  Future<int> getUnprocessedCount();
}

abstract class ICameraRepository {
  Future<CameraFeed> getPorchCamera();
  Future<bool> unlockPorchDoor({int durationSeconds = 5});
  Future<bool> toggleAlarm();
}

abstract class ISettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

abstract class IBackendBridge {
  IChatRepository get chats;
  IIncidentRepository get incidents;
  ICameraRepository get camera;
  ISettingsRepository get settings;
}
