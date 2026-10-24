# API Contract: Flutter → Spring Boot

**Проект:** Интеллектуальная система «Безопасная детская площадка»
**Версия:** 1.0
**Схема БД:** `playground_schema.sql` (таблицы `incident`, `stranger`, `person_whitelist`, `app_settings`)

---

## 0. Общие конвенции

| Правило | Значение |
|---|---|
| Base URL | `http://<host>:8080/api/v1` |
| Формат JSON | camelCase (`occurredAt`, `visitCount`, `snapshotUrl`) |
| Даты | ISO 8601 UTC с `Z`: `"2026-10-24T07:32:10Z"`. Перевод в локальное время — на фронте |
| Авторизация | Отсутствует (осознанное решение для демо-версии) |
| Медиа-ссылки | Относительные пути (`/media/snapshots/inc_42.jpg`), фронт приклеивает адрес сервера из настроек |
| Пагинация | Spring-стиль: `page` (с 0), `size`, ответ `{ content, page, size, totalElements, totalPages }` |
| Ошибки | Единый формат (см. ниже) |
| CORS | Включить для Flutter Web на Java-сервере |

**Формат ошибок:**

```json
{
  "code": "STRANGER_ALREADY_APPROVED",
  "message": "Незнакомец уже добавлен в белый список"
}
```

**Используемые HTTP-статусы:** `200`, `204`, `400`, `404`, `409`, `500`.

---

## 1. Инциденты (журнал)

### 1.1. `GET /api/v1/incidents`

Список инцидентов с фильтрацией. Сортировка по `occurredAt` DESC.

| Параметр | Тип | Обязателен | Описание |
|---|---|---|---|
| `type` | string | нет | `CAR_ON_PLAYGROUND` / `STRANGER_DETECTED` |
| `from` | ISO-дата | нет | начало диапазона по `occurredAt` |
| `to` | ISO-дата | нет | конец диапазона |
| `processed` | boolean | нет | фильтр «обработан / не обработан» |
| `page` | int | нет | дефолт `0` |
| `size` | int | нет | дефолт `20` |

**Ответ 200:**

```json
{
  "content": [
    {
      "id": 42,
      "type": "CAR_ON_PLAYGROUND",
      "occurredAt": "2026-10-24T07:32:10Z",
      "description": "Тревога! Автомобиль на детской площадке",
      "snapshotUrl": "/media/snapshots/inc_42.jpg",
      "trackId": 7,
      "confidence": 0.94,
      "processed": false,
      "processedAt": null,
      "stranger": null
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 137,
  "totalPages": 7
}
```

### 1.2. `GET /api/v1/incidents/{id}`

Детали инцидента. Для `STRANGER_DETECTED` вложена карточка человека.

**Ответ 200:**

```json
{
  "id": 51,
  "type": "STRANGER_DETECTED",
  "occurredAt": "2026-10-24T07:31:56Z",
  "description": "Обнаружен незнакомый посетитель",
  "snapshotUrl": null,
  "trackId": null,
  "confidence": 0.81,
  "processed": false,
  "processedAt": null,
  "stranger": {
    "id": 12,
    "bestSnapshotUrl": "/media/faces/s12.jpg",
    "visitCount": 4,
    "firstSeen": "2026-10-20T18:04:11Z",
    "lastSeen": "2026-10-24T07:31:56Z"
  }
}
```

**Ошибки:** `404` — инцидент не найден.

### 1.3. `PATCH /api/v1/incidents/{id}/acknowledge`

Пометить инцидент обработанным. Тела запроса нет.

**Ответ 200:** обновлённая карточка (`processed: true`, заполнен `processedAt`).
**Ошибки:** `404` — не найден.

### 1.4. `GET /api/v1/incidents/unprocessed/count` *(опционально)*

Счётчик необработанных — для бейджа на вкладке «Журнал».

**Ответ 200:**

```json
{ "count": 3 }
```

---

## 2. Незнакомцы (панель посетителей)

### 2.1. `GET /api/v1/strangers`

Только неодобренные (`whitelist_id IS NULL`). Сортировка по `visitCount` DESC.

| Параметр | Тип | Обязателен | Описание |
|---|---|---|---|
| `page` / `size` | int | нет | пагинация |

**Ответ 200** (та же пагинация, что в 1.1):

```json
{
  "content": [
    {
      "id": 12,
      "bestSnapshotUrl": "/media/faces/s12.jpg",
      "visitCount": 4,
      "firstSeen": "2026-10-20T18:04:11Z",
      "lastSeen": "2026-10-24T07:31:56Z"
    }
  ],
  "page": 0, "size": 20, "totalElements": 2, "totalPages": 1
}
```

### 2.2. `POST /api/v1/strangers/{id}/approve`

Одобрить незнакомца и добавить в белый список.

**Запрос:**

```json
{ "fullName": "Иванов Иван И." }
```

**Ответ 200:** созданная запись `person_whitelist` (WhitelistDTO из п. 3.1).

**Побочные эффекты на бекенде (внутренние):**
1. Создаётся запись в `person_whitelist`, эмбеддинг копируется из `stranger`.
2. `stranger.whitelist_id` = id новой записи (счётчик незнакомца замораживается).
3. Обновлённый список доверенных лиц синхронизируется с Python-модулем.

**Ошибки:** `404` — незнакомец не найден; `409` — уже одобрен.

### 2.3. `DELETE /api/v1/strangers/{id}` *(опционально)*

Удаление ложного распознавания. **Ответ:** `204`.

---

## 3. Белый список

### 3.1. `GET /api/v1/whitelist`

| Параметр | Тип | Обязателен | Описание |
|---|---|---|---|
| `status` | string | нет | `TRUSTED` / `PENDING` |

**Ответ 200:**

```json
[
  {
    "id": 3,
    "fullName": "Петрова А.С. (консьерж)",
    "photoUrl": "/media/faces/w3.jpg",
    "visitCount": 57,
    "status": "TRUSTED",
    "createdAt": "2026-10-01T09:00:00Z"
  }
]
```

### 3.2. `PUT /api/v1/whitelist/{id}/confirm`

Перевод статуса `PENDING → TRUSTED`. Тела нет. **Ответ 200:** WhitelistDTO.
Нужен только если используется статус `PENDING`.

### 3.3. `DELETE /api/v1/whitelist/{id}`

Удалить из белого списка. **Ответ:** `204`.
⚠️ Обязательно с пересинком в Python — иначе лицо останется в индексе и продолжит определяться как «Свой».

---

## 4. Система (статус-панель)

### 4.1. `GET /api/v1/system/status`

Фронт опрашивает раз в 5–10 секунд (WebSocket для этого не нужен).

**Ответ 200:**

```json
{
  "backend": true,
  "cvService": true,
  "camera": true,
  "lastIncidentAt": "2026-10-24T07:32:10Z",
  "streamUrl": "http://192.168.1.10:8000/video_feed"
}
```

| Поле | Смысл |
|---|---|
| `backend` | Java-сервер жив (это эндпоинт и есть доказательство) |
| `cvService` | Python-модуль отвечает (heartbeat по внутреннему пингу Java → Python) |
| `camera` | Источник видео доступен |
| `lastIncidentAt` | Время последнего события |
| `streamUrl` | **Полный** URL MJPEG-стрима (другой сервис, другой порт — поэтому абсолютный адрес, а не относительный путь) |

---

## 5. WebSocket — мгновенные алерты (не REST, но часть контракта)

| Параметр | Значение |
|---|---|
| Подключение | `ws://<host>:8080/ws` — **raw STOMP, без SockJS** (Flutter-клиент не поддерживает SockJS) |
| Подписка | `/topic/alerts` |
| Сообщение | AlertDTO = IncidentDTO (структура из п. 1.1) |

**Поведение клиента:**
- Получено сообщение → глобальный алерт-оверлей поверх любого экрана: красная пульсирующая рамка, баннер, сирена.
- Дедупликация по `trackId`: несколько событий одного трека → одно тревожное состояние, счётчик «×N».
- Кнопка «Принять» → `PATCH /api/v1/incidents/{id}/acknowledge`.

---

## 6. MJPEG-видеопоток

| Параметр | Значение |
|---|---|
| Источник | Python CV-сервис **напрямую** (Java не проксирует) |
| URL | Берётся из `system/status → streamUrl` или вводится в настройках |
| Формат | HTTP `multipart/x-mixed-replace` (MJPEG), рамки уже наложены на кадры |
| Переподключение | Автоматическое, с индикацией «Переподключение…» |

---

## 7. Сводный чек-лист эндпоинтов

| # | Метод | Путь | Приоритет | Экран |
|---|---|---|---|---|
| 1 | GET | `/api/v1/incidents` | P1 | Журнал |
| 2 | GET | `/api/v1/incidents/{id}` | P1 | Журнал — деталка |
| 3 | PATCH | `/api/v1/incidents/{id}/acknowledge` | P0 | Алерт-оверлей / Журнал |
| 4 | GET | `/api/v1/incidents/unprocessed/count` | P2 | Бейдж вкладки |
| 5 | GET | `/api/v1/strangers` | P1 | Посетители |
| 6 | POST | `/api/v1/strangers/{id}/approve` | P1 | Посетители |
| 7 | DELETE | `/api/v1/strangers/{id}` | P2 | Посетители |
| 8 | GET | `/api/v1/whitelist` | P1 | Посетители — «Свои» |
| 9 | PUT | `/api/v1/whitelist/{id}/confirm` | P2 | Посетители |
| 10 | DELETE | `/api/v1/whitelist/{id}` | P1 | Посетители |
| 11 | GET | `/api/v1/system/status` | P0 | Мониторинг — статус-панель |
| 12 | WS | `/ws` + `/topic/alerts` | P0 | Алерт-оверлей |
| 13 | HTTP | MJPEG `streamUrl` (Python) | P0 | Мониторинг — видео |

Приоритеты: **P0** — сценарий 1 защиты (машина на площадке), **P1** — сценарии 2–3, **P2** — полировка.

---

## 8. Замечания для Flutter-реализации

1. **HTTP-клиент:** `dio` (таймауты: connect 3 c, receive 5 c) или `http`. Один настроенный инстанс с базовым URL из настроек.
2. **Структура:** Repository-паттерн по фичам — `IncidentRepository`, `StrangerRepository`, `WhitelistRepository`, `SystemRepository` + `AlertStream` (WebSocket).
3. **Модели:** `fromJson`/`toJson` ручные или `json_serializable`; даты парсить как UTC и переводить в локальные только при показе.
4. **Ошибки:** маппинг статусов на понятные снекбары («Сервер недоступен», «Не найдено»), без крашей.
5. **Опрос:** `system/status` — Timer каждые 5–10 c; алерты — только WebSocket, без поллинга инцидентов.
6. **Пересинк списков:** после любого мутационного запроса (approve / delete / acknowledge) — перезапрос соответствующего списка.
7. **Никакой логики распознавания на клиенте** — фронт только отображает данные сервера.
