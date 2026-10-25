# Safe Playground Operator

Flutter client for the playground monitoring operator. The supported way to
run it is the containerised stack in the [root README](../README.md):

```bash
docker compose up --build -d
# http://localhost:5173
```

The image builds the **release** web bundle with the pinned Flutter SDK and
serves it through nginx, so no local Flutter install is required.

## Configuration

At build time the app reads `API_BASE_URL`:

- `/` (used by the Docker image) means "same origin as this page". nginx
  proxies `/api/` and `/media/` to the backend, so the app works from any host
  or LAN address without CORS.
- An absolute URL such as `http://localhost:8086` is used as-is.
  `String.fromEnvironment` means it is compiled in, not read at runtime:

  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8086
  ```

The default for a native/dev build is `http://localhost:8086`.

## Native development

Install Flutter 3.38.x, then:

```bash
flutter pub get
flutter run -d chrome --web-port 5173 \
  --dart-define=API_BASE_URL=http://localhost:8086
```

The backend's default CORS allow-list contains `http://localhost:5173`; a
different dev port needs to be added to `CORS_ALLOWED_ORIGINS`.

The backend can run from Docker or from Maven; see
[`backend/README.md`](../backend/README.md). Android emulator users should use
`http://10.0.2.2:8086`.

## Camera playback

The app renders the camera's `streamUrl` directly:

- **Web** — a plain `<img>` platform view. Browsers render
  `multipart/x-mixed-replace` (MJPEG) natively. RTSP cannot be played by a
  browser and is reported with a clear message.
- **Linux/Windows/mobile** — `media_kit` (mpv), which handles MJPEG, RTSP, and
  video files.

Point a camera entry at the hub:

```
http://localhost:8090/stream.mjpg
```

`0.0.0.0` is a bind address, not a destination: Chrome rejects it for image
subresources even though it works in the address bar. The player normalises it
to `127.0.0.1`; prefer `localhost` when creating the camera.

## Features

- Login with expiring bearer tokens; no public registration.
- Monitoring, incident journal, visitors, recordings, camera catalog, and
  account management.
- Administrators manage cameras, recordings, and accounts.
- Pull-to-refresh for the monitor, incidents, and visitors.

## Backend contract

The app expects these endpoints on `API_BASE_URL` and sends the login token as
a bearer authorization header:

- `POST /api/v1/auth/login`
- `GET /api/v1/incidents`
- `GET /api/v1/persons`, `POST /api/v1/persons/{id}/confirm`
- `GET /api/v1/cameras`, `GET /api/v1/recordings?cameraId=&from=&to=`
- Administrator-only camera, recording, and account endpoints.

See [`backend/README.md`](../backend/README.md) for request/response details.

## Tests

```bash
flutter test
flutter analyze
```
