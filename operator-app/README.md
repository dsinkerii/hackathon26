# Safe Playground Operator

Flutter client for the playground monitoring operator.

## Run

Install Flutter, then run from this directory:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's host-machine address. For desktop use
`http://localhost:8080`; for a physical device use the development machine's
reachable LAN address.

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

## Tests

```powershell
flutter test
```
