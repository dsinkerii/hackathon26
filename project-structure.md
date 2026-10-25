# Структура проекта «Безопасная детская площадка»

Монорепозиторий с тремя независимыми модулями по ролям из ТЗ: Python (компьютерное зрение), Java / Spring Boot (бизнес-логика), Flutter (клиент оператора).

## Дерево проекта

```
safe-playground/
├── README.md                    # описание, запуск, сценарии демо
├── docker-compose.yml           # PostgreSQL + Redis (опционально) + сервисы
├── .env.example
├── docs/
│   ├── architecture.md          # схема взаимодействия модулей
│   ├── api.md                   # REST / WebSocket контракты
│   └── demo-scenarios.md        # 3 сценария защиты
├── data/
│   ├── videos/                  # тестовые ролики (машина, проход людей)
│   ├── whitelist/               # эталонные фото «своих»
│   └── snapshots/               # стоп-кадры инцидентов
│
├── cv-service/                  # ===== МОДУЛЬ 1: Python =====
│   ├── requirements.txt
│   ├── config.yaml              # источник видео, полигон зоны, пороги, URL сервера
│   ├── main.py                  # точка входа: запуск пайплайна и HTTP-сервера
│   ├── app/
│   │   ├── pipeline.py          # главный цикл: кадр → детекция → трекинг → логика
│   │   ├── detection/
│   │   │   ├── detector.py      # YOLO (person, car, truck, motorcycle)
│   │   │   └── tracker.py       # ByteTrack, присвоение ID
│   │   ├── zones/
│   │   │   ├── polygon.py       # загрузка полигона, point-in-polygon
│   │   │   └── vehicle_monitor.py  # логика «машина в зоне» + дедупликация тревог
│   │   ├── faces/
│   │   │   ├── face_engine.py   # эмбеддинги (DeepFace / InsightFace)
│   │   │   ├── whitelist.py     # локальная база эмбеддингов, сравнение
│   │   │   └── stranger_stats.py   # счётчик появлений незнакомцев
│   │   ├── events/
│   │   │   ├── models.py        # схема события (тип, время, координаты, кадр)
│   │   │   └── publisher.py     # HTTP POST / Redis → Java-сервер
│   │   ├── streaming/
│   │   │   ├── overlay.py       # рамки, ID, статусы, цвета (зелёный/красный)
│   │   │   └── mjpeg_server.py  # раздача MJPEG (FastAPI/Flask)
│   │   ├── sync/
│   │   │   └── whitelist_sync.py  # приём обновлённого белого списка от Java
│   │   └── utils/
│   │       └── snapshot.py      # сохранение стоп-кадра
│   └── tests/
│
├── backend/                     # ===== МОДУЛЬ 2: Java / Spring Boot =====
│   ├── pom.xml (или build.gradle)
│   └── src/
│       ├── main/
│       │   ├── java/com/playground/security/
│       │   │   ├── SecurityApplication.java
│       │   │   ├── config/
│       │   │   │   ├── WebSocketConfig.java   # STOMP-брокер
│       │   │   │   ├── CorsConfig.java
│       │   │   │   └── AppProperties.java     # пути, URL cv-service
│       │   │   ├── controller/
│       │   │   │   ├── IncidentController.java   # POST/GET /api/v1/incidents
│       │   │   │   └── WhitelistController.java  # CRUD /api/v1/persons, confirm
│       │   │   ├── service/
│       │   │   │   ├── IncidentService.java      # валидация, сохранение, вещание
│       │   │   │   ├── WhitelistService.java     # управление списком
│       │   │   │   ├── AlertBroadcaster.java     # отправка в /topic/alerts
│       │   │   │   └── CvSyncService.java        # синхронизация с Python-модулем
│       │   │   ├── entity/
│       │   │   │   ├── Incident.java
│       │   │   │   ├── PersonWhitelist.java
│       │   │   │   ├── IncidentType.java         # enum
│       │   │   │   └── PersonStatus.java         # enum: СВОЙ / НА_РАССМОТРЕНИИ
│       │   │   ├── repository/
│       │   │   │   ├── IncidentRepository.java
│       │   │   │   └── PersonWhitelistRepository.java
│       │   │   ├── dto/
│       │   │   │   ├── IncidentRequest.java
│       │   │   │   ├── IncidentResponse.java
│       │   │   │   └── AlertMessage.java
│       │   │   └── exception/
│       │   │       └── GlobalExceptionHandler.java
│       │   └── resources/
│       │       ├── application.yml
│       │       └── db/migration/ (или schema.sql)
│       └── test/
│
└── operator-app/                # ===== МОДУЛЬ 3: Flutter =====
    ├── pubspec.yaml
    ├── assets/
    │   └── sounds/siren.mp3
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── config.dart            # адреса сервера и MJPEG
        │   ├── theme.dart
        │   └── api_client.dart        # REST (dio/http)
        ├── models/
        │   ├── incident.dart
        │   └── person.dart
        ├── services/
        │   ├── websocket_service.dart # STOMP-клиент, поток алертов
        │   ├── audio_service.dart     # сирена
        │   └── connection_monitor.dart  # статус сервера/камеры
        ├── state/                     # Provider / Riverpod / Bloc
        │   ├── alert_provider.dart
        │   ├── incidents_provider.dart
        │   └── visitors_provider.dart
        ├── screens/
        │   ├── monitoring_screen.dart # видеоплеер + статусная панель
        │   ├── incidents_screen.dart  # журнал с фильтрами
        │   ├── incident_detail.dart   # стоп-кадр
        │   └── visitors_screen.dart   # карточки незнакомцев
        └── widgets/
            ├── mjpeg_player.dart
            ├── alert_overlay.dart     # красная пульсирующая рамка + баннер
            ├── status_panel.dart
            ├── incident_table.dart
            └── visitor_card.dart      # кнопка «Добавить в белый список»
```

## Ключевые потоки данных

1. **Тревога по машине:** `vehicle_monitor` → `publisher` (POST `/api/v1/incidents`) → `IncidentService` сохраняет и через `AlertBroadcaster` отправляет в STOMP → `websocket_service` во Flutter → `alert_overlay` + `audio_service`.
2. **Незнакомец:** `face_engine` + `whitelist` → статус «Незнакомый» → событие в журнал; `stranger_stats` накапливает визиты → Java создаёт запись «На рассмотрении» → карточка во Flutter.
3. **Белый список:** кнопка во Flutter → `WhitelistController` (confirm) → `CvSyncService` → `whitelist_sync` в Python → рамка становится зелёной со статусом «Свой».

## Соответствие сценариям защиты

| Сценарий | Задействованные компоненты |
|---|---|
| 1. Проезд машины | `detector`, `tracker`, `vehicle_monitor`, `publisher`, `IncidentService`, `AlertBroadcaster`, `alert_overlay`, `audio_service` |
| 2. Фиксация незнакомца | `face_engine`, `whitelist`, `stranger_stats`, `IncidentService`, `incidents_screen` |
| 3. Белый список | `visitor_card`, `WhitelistController`, `CvSyncService`, `whitelist_sync`, `overlay` |

## Рекомендации по реализации

- Для требования 1–2 секунды отправляйте событие тревоги в отдельном потоке (не блокируя цикл обработки кадров) и добавьте cooldown на повторные тревоги по одному ID трека.
- Для демо проще использовать H2/SQLite и HTTP POST вместо Redis; Redis можно оставить как расширение.
- MJPEG удобно отдавать через FastAPI (`StreamingResponse`), во Flutter показывать через `flutter_mjpeg` или собственный виджет.
- Начните с контрактов (`docs/api.md`): тогда три модуля можно разрабатывать параллельно.
