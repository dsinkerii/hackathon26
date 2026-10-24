# cv-service — модуль видеоаналитики

События на детской площадке: детекция машин в запретной зоне и фиксация
незнакомцев. Публикация — `POST /api/v1/incidents` на Java-бэкенд с заголовком
`X-Ingest-Token`.

## Два режима

| Режим | Что делает | Зависимости |
|---|---|---|
| `simulator` (по умолчанию) | Синтезирует событий типа `CAR_ON_PLAYGROUND` / `STRANGER_DETECTED` и шлёт их в бэкенд. Полная демо-цепочка без ML. | только стандартная библиотека (+ PyYAML для config.yaml) |
| `video` / `camera` | Реальный пайплайн: кадры OpenCV → YOLOv8 трекинг → проверка полигона зоны → кулдаун → снапшот JPEG → ingest. | `pip install -r requirements-cv.txt` |

## Быстрый старт

```powershell
# без установки всего
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
py main.py --once            # одно событие в бэкенд
py main.py --interval 8      # поток событий каждые ~8 с (Ctrl+C — стоп)
py main.py --dry-run         # напечатать событие, ничего не отправляя
```

Реальный пайплайн по видео/камере:

```powershell
pip install -r requirements.txt -r requirements-cv.txt
py main.py --source video    # ролик из config.yaml (source.video_path)
py main.py --source camera   # веб-камера (source.camera_index)
```

## Настройка

`config.yaml` — источник события, полигон зоны, пороги, URL бэкенда.
Переменные окружения приоритетнее файла:

| Переменная | Назначение |
|---|---|
| `PLAYGROUND_API_URL` | Базовый URL бэкенда (по умолчанию `http://localhost:8080`) |
| `INGEST_API_TOKEN` | Токен ingest, тот же, что у бэкенда |

## Что дальше (roadmap)

- ByteTrack поверх YOLO и стабильные «человеческие» track_id.
- InsightFace/DeepFace: сравнение с белым списком (требует контракт синка
  `CvSyncService` ↔ `whitelist_sync`) — пока «незнакомец» создаётся на каждое
  событие без `personId`.
- MJPEG-стрим для вкладки «Мониторинг» пульта.
- Клиентский кэш эмбеддингов «своих».
