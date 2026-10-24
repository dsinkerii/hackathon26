# Safe Playground — «Безопасная детская площадка»

Интеллектуальная система мониторинга детской площадки во дворе жилого комплекса:
видеоаналитика (Python), сервер бизнес-логики (Java / Spring Boot), пульт оператора
охраны (Flutter).

Система детектирует автомобили в запретной зоне (детская площадка), регистрирует
незнакомых посетителей и мгновенно передаёт тревожные события на пульт оператора
(Server-Sent Events, push < 1–2 сек от момента ingest).

## Структура репозитория

| Папка | Модуль | Статус |
|---|---|---|
| `backend/` | Java 17 / Spring Boot 3.3 — REST, SSE-алерты, H2/PostgreSQL, Flyway | ✅ MVP |
| `operator-app/` | Flutter — пульт оператора (web/windows): мониторинг, журнал, посетители, живые алерты по SSE | ✅ MVP |
| `cv-service/` | Python — события в запретную зону: режим `simulator` (работает без ML) + YOLO-пайплайн по видео/камере | 🟡 каркас готов, лица — в планах |

Контракт API и переменные окружения: `backend/README.md` (раздел «API»),
краткое описание CV-модуля — `cv-service/README.md`.

## Быстрый старт backend

1. Поднять БД: `docker compose up -d` (PostgreSQL 16, порт 5432, логин/пас: playground / playground)
2. Запустить backend с профилем `postgres`:
   - IntelliJ: Run Configuration → Active profiles: `postgres`
   - или CLI: `mvn spring-boot:run -Dspring-boot.run.profiles=postgres`
3. Flyway автоматически применит миграции при первом старте
4. Разработка без Docker: профиль `h2` включён по умолчанию (файл БД `backend/data/`)
5. Переменные окружения для запуска: `INGEST_API_TOKEN` — секрет CV→бэкенд;
   для демо: `DEMO_MODE=true` (см. ниже)

## Быстрый старт CV-модуля

```powershell
cd cv-service
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
py main.py --once       # одно тестовое событие в бэкенд
py main.py              # поток синтетических событий каждые ~14 с
```

Без ML-зависимостей: режим `simulator` идёт из коробки. Реальный пайплайн
(YOLO по видео/камере) — `pip install -r requirements-cv.txt` и `py main.py --source video`.

## Быстрый старт пульта оператора

```powershell
cd operator-app
flutter run -d windows            # или -d chrome
```

Адрес API задаётся при сборке: `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
(по умолчанию `http://localhost:8080`). Пульт слушает `GET /api/v1/alerts/stream`
(Server-Sent Events): новая тревога мгновенно обновляет журналы и всплывает баннером.

## Демо-режим

Запусти backend с `DEMO_MODE=true` и перед показом сбрось данные:

```powershell
$env:DEMO_MODE = "true"
mvn spring-boot:run
# в другом окне:
curl -X POST http://localhost:8080/api/v1/demo/reset
```

В журнале появятся 5 инцидентов (машины + незнакомцы, события «свежие», со сдвигом
от текущего времени) и 3 посетителя, включая «свой» статус для одного из них.

## Статус работ

- [x] Backend: каркас Spring Boot + Flyway (H2/PostgreSQL), docker-compose БД
- [x] Backend: единые ошибки (`common/`), ingest с токеном и дедупликацией по track_id
- [x] Backend: SSE-пуш алертов `/api/v1/alerts/stream` + heartbeat
- [x] Backend: демо-сидер `POST /api/v1/demo/reset` (только при `DEMO_MODE=true`)
- [x] Flutter: пульт (мониторинг / журнал / посетители / записи), репозиторий с тестами
- [x] Flutter: живые алерты по SSE (баннер + автообновление)
- [x] CV: каркас `cv-service` с режимом simulator (push без ML) и конфигом зоны
- [ ] CV: реальный режим по камере/ролику — набор тестовых роликов, отладка полигона
- [ ] CV+Java: InsightFace-распознавание «свой/незнакомец» и синк белого списка
- [ ] WebSocket/STOMP вместо SSE (опционально, если понадобится брокер)
- [ ] MJPEG-стрим во вкладку «Мониторинг» пульта
- [ ] Итоговая проверка сценария «незнакомец стал своим» с зелёной рамкой в CV
