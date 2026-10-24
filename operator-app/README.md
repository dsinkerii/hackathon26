# Safe Playground Operator

Flutter client for the playground monitoring operator.

## Run

Install Flutter, then run from this directory:

```powershell
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5173 `
  --dart-define=API_BASE_URL=http://localhost:8080
```

Open `http://localhost:5173` to use the web app. The API remains a separate
backend service at `http://localhost:8080` by default. Override the API address
with `--dart-define=API_BASE_URL=...` when the backend runs elsewhere. The
default API URL is `http://localhost:8080`; Android emulator users should set
it to `http://10.0.2.2:8080`.

## Backend contract

The app expects these endpoints on `API_BASE_URL`:

- `GET /api/v1/incidents` — JSON array of incidents with `id`, `type`, and ISO
  8601 `occurredAt`; optional `description` and `snapshotUrl`.
- `GET /api/v1/persons` — JSON array of visitors with `id`, `status`, and ISO
  8601 `firstSeenAt`; optional `displayName`, `visitCount`, and `photoUrl`.
  A visitor with status `PENDING` or `НА_РАССМОТРЕНИИ` can be confirmed.
- `POST /api/v1/persons/{id}/confirm` — confirms a pending visitor. A 2xx
  response indicates success.

The monitor, incident list, and visitor list can be refreshed with pull-to-refresh.
The client currently uses REST polling on demand; live STOMP alerts and MJPEG
video playback require the corresponding backend services and are not wired yet.

The video archive currently has one clearly labeled playback test fixture. Its
flower clip is served by [MDN's CC0 video example](https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4)
and is not footage from the playground. The candidate Mixkit playground clip
listed in the supplied research notes is marked for personal use only, so it is
not embedded in the application. Replace the fixture with recordings from the
video service before using the archive as a real monitoring feature.

## Tests

```powershell
flutter test
```
