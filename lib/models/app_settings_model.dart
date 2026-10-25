import 'package:flutter/material.dart';

class AppSettings {
  final String userName;
  final String apartment;
  final String address;
  final ThemeMode themeMode;
  final Color seedColor;
  final bool notificationsEnabled;
  final String backendUrl;

  const AppSettings({
    this.userName = 'Олег Смирнов',
    this.apartment = 'кв. 42',
    this.address = 'Ул. Пушкина, дом Колотушкина',
    this.themeMode = ThemeMode.system,
    this.seedColor = const Color(0xFF6750A4), // Penpot M3 default primary
    this.notificationsEnabled = true,
    this.backendUrl = 'http://localhost:8080/api/v1',
  });

  AppSettings copyWith({
    String? userName,
    String? apartment,
    String? address,
    ThemeMode? themeMode,
    Color? seedColor,
    bool? notificationsEnabled,
    String? backendUrl,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      apartment: apartment ?? this.apartment,
      address: address ?? this.address,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      backendUrl: backendUrl ?? this.backendUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'apartment': apartment,
      'address': address,
      'themeMode': themeMode.name,
      'seedColor': seedColor.toARGB32(),
      'notificationsEnabled': notificationsEnabled,
      'backendUrl': backendUrl,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    ThemeMode mode = ThemeMode.system;
    if (json['themeMode'] == 'light') mode = ThemeMode.light;
    if (json['themeMode'] == 'dark') mode = ThemeMode.dark;

    return AppSettings(
      userName: json['userName'] ?? 'Олег Смирнов',
      apartment: json['apartment'] ?? 'кв. 42',
      address: json['address'] ?? 'Ул. Пушкина, дом Колотушкина',
      themeMode: mode,
      seedColor: json['seedColor'] != null
          ? Color(json['seedColor'] as int)
          : const Color(0xFF6750A4),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      backendUrl: json['backendUrl'] ?? 'http://localhost:8080/api/v1',
    );
  }
}
