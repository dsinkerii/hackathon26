# Структура бекенда: Spring Boot

**Проект:** Интеллектуальная система «Безопасная детская площадка»
**Модуль:** Java / Spring Boot (сервер бизнес-логики)
**Связанные документы:** `playground_schema.sql` (схема БД), `playground_api_contract.md` (контракт с Flutter)

---

## 1. Дерево проекта

```
playground-backend/
├── pom.xml
├── docker-compose.yml                          # pg + backend (опционально)
└── src/
    ├── main/resources/
    │   ├── application.yml                     # профили: postgres (демо) / h2 (разработка)
    │   ├── db/migration/V1__init.sql           # = playground_schema.sql
    │   └── static/media/
    │       ├── snapshots/                      # стоп-кадры инцидентов
    │       └── faces/                          # кропы лиц (незнакомцы, эталоны whitelist)
    └── java/.../playground/
        ├── PlaygroundApplication.java
        │
        ├── config/
        │   ├── WebSocketConfig.java
        │   ├── WebConfig.java
        │   └── JacksonConfig.java
        │
        ├── common/
        │   ├── ErrorCode.java
        │   ├── ApiException.java
        │   └── GlobalExceptionHandler.java
        │
        ├── incident/
        │   ├── Incident.java
        │   ├── IncidentType.java
        │   ├── IncidentRepository.java
        │   ├── IncidentService.java
        │   ├── IncidentController.java
        │   ├── IncidentIngestController.java
        │   └── dto/
        │       ├── IncidentDto.java
        │       ├── IngestRequest.java
        │       └── PageResponse.java
        │
        ├── stranger/
        │   ├── Stranger.java
        │   ├── StrangerRepository.java
        │   ├── StrangerService.java
        │   ├── StrangerController.java
        │   └── dto/
        │       └── StrangerDto.java
        │
        ├── whitelist/
        │   ├── PersonWhitelist.java
        │   ├── PersonStatus.java
        │   ├── WhitelistRepository.java
        │   ├── WhitelistService.java
        │   ├── WhitelistController.java
        │   └── dto/
        │       └── WhitelistDto.java
        │
        ├── alerts/
        │   └── AlertBroadcaster.java
        │
        ├── sync/
        │   └── CvSyncClient.java
        │
        ├── system/
        │   ├── SystemStatusService.java
        │   ├── SystemStatusController.java
        │   └── dto/
        │       └── SystemStatusDto.java
        │
        └── media/
            └── MediaStorageService.java
```

**Итого:** ~30 файлов, из них содержательных — около десяти (сервисы, broadcaster, sync-клиент, конфиги). Остальное — бойлерплейт Spring.

---

## 2. Ответственность по файлам

### 2.1. Корень и ресурсы

| Файл | Что реализовать |
|---|---|
| `pom.xml` | Зависимости: `spring-boot-starter-web`, `spring-boot-starter-websocket`, `spring-boot-starter-data-jpa`, `spring-boot-starter-validation`, драйверы PostgreSQL + H2, Flyway, Lombok (по желанию) |
| `application.yml` | Профили: `postgres` (jdbc:postgresql://localhost:5432/playground) и `h2` (jdbc:h2:file:./data/playground). Порт 8080. Размер загрузки multipart: 10 MB |
| `V1__init.sql` | Миграция = наш DDL (4 таблицы + индексы). Для профиля H2 — вариант с `BIGINT AUTO_INCREMENT` / `TIMESTAMP` |
| `static/media/` | Целевая папка картинок. Раздаётся через ResourceHandler из `WebConfig` |

### 2.2. config/ — три конфига, три «засады»

| Файл | Что реализовать | Критично |
|---|---|---|
| `WebSocketConfig.java` | STOMP-брокер: endpoint `/ws`, префикс подписок `/topic`. Реестр сообщений для алертов | ⚠️ **Без `.withSockJS()`** — Flutter работает только с raw WebSocket |
| `WebConfig.java` | 1) CORS: разрешить origin Flutter (или `*` для демо). 2) ResourceHandler: `/media/**` → `classpath:/static/media/` | Без CORS фронт на Web не подключится; без ResourceHandler стоп-кадры будут битыми |
| `JacksonConfig.java` | Сериализация дат строго ISO-8601 UTC (`WRITE_DATES_AS_TIMESTAMPS` off, формат с `Z`) | Иначе фронт получит даты в дефолтном формате и сломает парсинг |

### 2.3. common/ — единые ошибки (пишется один вечер, выглядит взросло)

| Файл | Что реализовать |
|---|---|
| `ErrorCode.java` | Enum кодов из контракта: `INCIDENT_NOT_FOUND`, `STRANGER_NOT_FOUND`, `STRANGER_ALREADY_APPROVED`, `VALIDATION_ERROR`, ... |
| `ApiException.java` | Runtime-исключение: `code` + `message` + HTTP-статус |
| `GlobalExceptionHandler.java` | `@RestControllerAdvice`: перехват `ApiException`, `MethodArgumentNotValidException` (400), общих Exception (500). Ответ строго `{ "code": "...", "message": "..." }` |

### 2.4. incident/ — самое большое место работы

| Файл | Что реализовать |
|---|---|
| `Incident.java` | JPA-сущность таблицы `incident`. Enum `type` через `@Enumerated(EnumType.STRING)`. Таймстампы: `@CreationTimestamp` на created_at. Связь `@ManyToOne` на Stranger, **nullable**, fetch LAZY. Имена колонок — как в DDL |
| `IncidentType.java` | Enum: `CAR_ON_PLAYGROUND`, `STRANGER_DETECTED`. Метод `defaultMessage()` — готовый текст для UI («Тревога! Автомобиль на детской площадке» / «Обнаружен незнакомый посетитель») |
| `IncidentRepository.java` | `JpaRepository` + `@Query` для списка с фильтрами (type / from / to / processed + `Pageable`, сортировка `occurredAt DESC`). Отдельные методы: `countByProcessedFalse()`, `findFirstByTrackIdAndOccurredAtAfter(...)` — для дедупликации |
| `IncidentService.java` | **Вся бизнес-логика:** 1) приём события от Python: валидация (тип, время, координаты), 2) **дедупликация**: инцидент по тому же `trackId` за окном N секунд (настраивается в `app_settings`) → не создавать дубликат, 3) для `STRANGER_DETECTED` — матчинг/создание незнакомца (см. 2.5), 4) `acknowledge`: `processed=true`, `processedAt=now()`, 5) сохранение стоп-кадра через `MediaStorageService` |
| `IncidentIngestController.java` | `POST /api/v1/incidents` — **внутренний эндпоинт для Python** (не путать с GET для фронта). Тело: `IngestRequest`. После сохранения вызывает `AlertBroadcaster`. Проставляет `description` из `IncidentType.defaultMessage()`, если Python не прислал свой |
| `IncidentController.java` | Фронтовская четвёрка из контракта: `GET /incidents` (фильтры + пагинация → `PageResponse`), `GET /incidents/{id}` (деталка, stranger вложен, 404), `PATCH /incidents/{id}/acknowledge`, `GET /incidents/unprocessed/count` |
| `dto/IncidentDto.java` | Ровно как в контракте: `id, type, occurredAt, description, snapshotUrl, trackId, confidence, processed, processedAt, stranger (StrangerDto \| null)` |
| `dto/IngestRequest.java` | Вход от Python: `type`, `occurredAt` (UTC), `trackId`, `confidence`, `snapshotBase64` (или multipart — см. решения), `faceEmbedding` (для незнакомца, JSON-массив float), `faceSnapshotBase64` |
| `dto/PageResponse.java` | Обёртка `{ content, page, size, totalElements, totalPages }` — единая для всех списков |

### 2.5. stranger/ — учёт незнакомцев

| Файл | Что реализовать |
|---|---|
| `Stranger.java` | JPA-сущность `stranger`: эмбеддинг (TEXT), `bestSnapshotUrl`, `firstSeen`, `lastSeen`, `visitCount`, ссылка на whitelist (nullable). NOT NULL на whitelist_id = одобрен |
| `StrangerRepository.java` | `findByWhitelistIdIsNullOrderByVisitCountDesc(Pageable)` — панель незнакомцев. Плюс `findByWhitelistIdIsNull()` — полный список для матчинга |
| `StrangerService.java` | **Ключевая логика:** 1) **матчинг входящего лица**: cosine similarity эмбеддинга события с эмбеддингами неодобренных незнакомцев; порог (например 0.5, из `app_settings`) → существующий: `visitCount++`, `lastSeen=now()`, обновить best-кроп при лучшем качестве; иначе новый Stranger. 2) **апрув**: создать `PersonWhitelist` (скопировать эмбеддинг!), проставить `whitelist_id` → счётчик заморожен, дёрнуть `CvSyncClient.resyncWhitelist()`. 3) Удаление ложного распознавания |
| `StrangerController.java` | `GET /strangers` (только неодобренные, пагинация), `POST /strangers/{id}/approve` (тело `{fullName}`, ошибки 404/409), `DELETE /strangers/{id}` (204) |
| `dto/StrangerDto.java` | `id, bestSnapshotUrl, visitCount, firstSeen, lastSeen` — как в контракте |

> **Зафиксированное решение:** матчинг незнакомцев и счётчик визитов ведёт **Java**, Python — stateless по личностям: он проверяет «свой/не свой» по whitelist (для рамок на видео) и шлёт вверх эмбеддинг + кроп. Единый источник правды — БД.

### 2.6. whitelist/ — доверенные лица

| Файл | Что реализовать |
|---|---|
| `PersonWhitelist.java` | JPA-сущность `person_whitelist`. Enum `PersonStatus`: `TRUSTED`, `PENDING` (`@Enumerated(STRING)`) |
| `WhitelistRepository.java` | `findByStatus(...)`, обычный CRUD |
| `WhitelistService.java` | list, `confirm` (PENDING → TRUSTED), **delete с обязательным вызовом `CvSyncClient.resyncWhitelist()`** — иначе удалённое лицо продолжит опознаваться как «Свой» |
| `WhitelistController.java` | `GET /whitelist?status=`, `PUT /whitelist/{id}/confirm`, `DELETE /whitelist/{id}` (204) |
| `dto/WhitelistDto.java` | `id, fullName, photoUrl, visitCount, status, createdAt` |

### 2.7. alerts / sync / system / media — инфраструктура

| Файл | Что реализовать |
|---|---|
| `alerts/AlertBroadcaster.java` | Обёртка над `SimpMessagingTemplate`: `convertAndSend("/topic/alerts", incidentDto)`. Вызывается из ingest-контроллера. Именно этот путь обеспечивает задержку < 1–2 c из ТЗ |
| `sync/CvSyncClient.java` | HTTP-клиент (RestClient/WebClient) к Python: 1) `resyncWhitelist()` — POST/PUT полного списка `{id, embedding}`; 2) `ping()` — проверка живости CV-сервиса и камеры. **Таймауты 2–3 c, ошибки глотать с логом** — статус-панель не должна падать, если Python спит |
| `system/SystemStatusService.java` | Агрегат: `backend=true` (раз ответили), `cvService` / `camera` (из `CvSyncClient.ping()`), `lastIncidentAt` (из БД), `streamUrl` (из `app_settings`) |
| `system/SystemStatusController.java` | `GET /api/v1/system/status` → `SystemStatusDto`. Фронт опрашивает раз в 5–10 c |
| `media/MediaStorageService.java` | Принять байты JPEG (base64 из ingest), сохранить в `static/media/snapshots/` или `/faces/` с именем `inc_{id}.jpg` / `s{id}_{n}.jpg`, вернуть относительный URL `/media/...` |

### 2.8. settings (опционально)

Таблица `app_settings` читается напрямую (`JdbcTemplate` или простой entity) для: координат зоны, порога similarity, cooldown дедупликации, streamUrl. Отдельный REST-контроллер для настроек не требуется контрактом.

---

## 3. Зафиксированные архитектурные решения

| # | Решение | Мотивация |
|---|---|---|
| 1 | WebSocket — **raw STOMP, без SockJS** | Flutter-клиент не поддерживает SockJS |
| 2 | Матчинг незнакомцев и `visit_count` — в Java/БД | Единый источник правды; Python остаётся stateless по личностям |
| 3 | Дедупликация алертов — по `track_id` + cooldown (в Java при ingest) | Иначе журнал замусоривается повторами по одному событию |
| 4 | Медиа хранит и раздаёт **Java** (`/media/**`), относительные пути в БД | Смена сервера в настройках фронта не ломает картинки |
| 5 | Даты — UTC в БД и JSON, ISO-8601 | Python в Docker-контейнере может жить в другой таймзоне |
| 6 | Единый формат ошибок `{code, message}` | Контракт с фронтом, снекбары без парсинга текста |
| 7 | Пересинк whitelist в Python при **любой** мутации списка | Иначе рамки «Свой» на видео разъезжаются с реальностью |

**Открытый вопрос (решить до кода ingest):** как Python передаёт стоп-кадры — base64 в JSON тела `POST /api/v1/incidents` (проще, один запрос) или multipart-загрузка отдельным запросом (чище для больших кадров). Для демо-масштаба рекомендация: **base64 в JSON**.

---

## 4. Порядок реализации (по зависимостям)

| Шаг | Файлы | Результат |
|---|---|---|
| 1 | `pom.xml`, `application.yml`, `V1__init.sql`, entity + repository (все 3 пакета) | Каркас: БД поднимается, миграция применяется |
| 2 | `common/*`, `JacksonConfig` | Готова система ошибок и дат для всех контроллеров |
| 3 | `MediaStorageService`, `IncidentIngestController`, `IncidentService` | Приём событий от Python — можно тестировать curl'ом |
| 4 | `WebSocketConfig`, `AlertBroadcaster` | Алерты уходят в `/topic/alerts` — сценарий 1 закрыт на беке |
| 5 | `IncidentController`, dto | Журнал для Flutter |
| 6 | `StrangerService/Controller`, `WhitelistService/Controller`, `CvSyncClient` | Сценарии 2–3 + пересинк |
| 7 | `SystemStatus*` | Статус-панель, полировка |

Проверка каждого шага — curl / Postman до появления Flutter: шаг 3 тестируем эмуляцией Python-события, шаг 4 — wscat / STOMP-клиентом.
