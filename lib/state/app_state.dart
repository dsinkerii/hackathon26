import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings_model.dart';
import '../models/camera_model.dart';
import '../models/chat_model.dart';
import '../models/incident_model.dart';
import '../services/backend_bridge.dart';
import '../services/mock_backend_bridge.dart';

class AppState extends ChangeNotifier {
  final IBackendBridge bridge;

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  List<Chat> _chats = [];
  List<Chat> get chats => _chats;

  List<Incident> _incidents = [];
  List<Incident> get incidents => _incidents;

  CameraFeed? _porchCamera;
  CameraFeed? get porchCamera => _porchCamera;

  int _unprocessedIncidentsCount = 0;
  int get unprocessedIncidentsCount => _unprocessedIncidentsCount;

  bool _isDoorUnlocking = false;
  bool get isDoorUnlocking => _isDoorUnlocking;

  int _doorCountdown = 0;
  int get doorCountdown => _doorCountdown;

  Timer? _countdownTimer;

  AppState({IBackendBridge? backendBridge})
      : bridge = backendBridge ?? MockBackendBridge() {
    refreshAll();
  }

  void selectTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _settings = await bridge.settings.getSettings();
    _chats = await bridge.chats.getChats();
    _incidents = await bridge.incidents.getIncidents();
    _unprocessedIncidentsCount = await bridge.incidents.getUnprocessedCount();
    _porchCamera = await bridge.camera.getPorchCamera();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await bridge.settings.saveSettings(newSettings);
    notifyListeners();
  }

  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await bridge.chats.sendMessage(chatId, text.trim());
    _chats = await bridge.chats.getChats();
    notifyListeners();

    // Refresh after potential auto-reply
    Future.delayed(const Duration(milliseconds: 2200), () async {
      _chats = await bridge.chats.getChats();
      notifyListeners();
    });
  }

  Future<void> markChatAsRead(String chatId) async {
    await bridge.chats.markAsRead(chatId);
    _chats = await bridge.chats.getChats();
    notifyListeners();
  }

  Future<void> acknowledgeIncident(int id) async {
    await bridge.incidents.acknowledgeIncident(id);
    _incidents = await bridge.incidents.getIncidents();
    _unprocessedIncidentsCount = await bridge.incidents.getUnprocessedCount();
    notifyListeners();
  }

  Future<void> approveStranger(int strangerId, String fullName) async {
    await bridge.incidents.approveStranger(strangerId, fullName);
    _incidents = await bridge.incidents.getIncidents();
    _unprocessedIncidentsCount = await bridge.incidents.getUnprocessedCount();
    notifyListeners();
  }

  Future<void> unlockDoor() async {
    if (_isDoorUnlocking) return;

    _isDoorUnlocking = true;
    _doorCountdown = 10;
    await bridge.camera.unlockPorchDoor(durationSeconds: 10);
    _porchCamera = await bridge.camera.getPorchCamera();
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_doorCountdown > 1) {
        _doorCountdown--;
        notifyListeners();
      } else {
        _doorCountdown = 0;
        _isDoorUnlocking = false;
        timer.cancel();
        refreshCamera();
      }
    });
  }

  Future<void> refreshCamera() async {
    _porchCamera = await bridge.camera.getPorchCamera();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
