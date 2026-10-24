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

## Admin site and authorization

The web client now requires an account. Start the backend with
`JWT_SECRET`, `INITIAL_ADMIN_USERNAME`, and `INITIAL_ADMIN_PASSWORD` set as
described in [the backend README](../backend/README.md). The bootstrap
administrator can create operator/admin accounts in **Доступ**; public signup
is disabled. Sessions use expiring bearer tokens.

Administrators can manage camera catalog entries, recording metadata, and
accounts. The **Видеоархив** view filters across all cameras or one selected
camera and by date range. Recording entries contain links to video files
provided by an external archive service; the backend does not upload or own
the underlying footage. Connect a camera/archive source and register its
recording URLs before expecting real footage.

## Backend contract

The app expects these endpoints on `API_BASE_URL` and sends the login token as a
bearer authorization header:

- `POST /api/v1/auth/login`
- `GET /api/v1/incidents` — JSON array of incidents with `id`, `type`, and ISO
  8601 `occurredAt`; optional `description` and `snapshotUrl`.
- `GET /api/v1/persons` — JSON array of visitors with `id`, `status`, and ISO
  8601 `firstSeenAt`; optional `displayName`, `visitCount`, and `photoUrl`.
  A visitor with status `PENDING` or `НА_РАССМОТРЕНИИ` can be confirmed.
- `POST /api/v1/persons/{id}/confirm` — confirms a pending visitor. A 2xx
  response indicates success.
- `GET /api/v1/cameras` and `GET /api/v1/recordings?cameraId=&from=&to=`.
- Administrator-only camera, recording, and account management endpoints.

The monitor, incident list, and visitor list can be refreshed with pull-to-refresh.
The client currently uses REST polling on demand; live STOMP alerts and MJPEG
video playback require the corresponding backend services and are not wired yet.

Live STOMP alerts and camera-stream playback still require integration with the
CV/video services. The archive no longer substitutes a third-party sample clip
for real recordings.

## Tests

```powershell
flutter test
```
