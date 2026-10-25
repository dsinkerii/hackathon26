# Safe Playground Backend

Spring Boot REST backend for the Flutter operator app.

## Docker (recommended)

The normal way to run it is from the repository root:

```bash
docker compose up --build -d backend
```

It listens on <http://localhost:8086> and persists the H2 database plus
uploaded media in the `backend-data` volume. Environment defaults, secrets,
and the bootstrap administrator are configured in the root
`.env.example` / [`docker-compose.yml`](../docker-compose.yml).

The web container proxies `/api/` and `/media/` to this service, so the Flutter
app does not need CORS.

## Local run

Requires Java 17 and Maven. From this directory:

```bash
export INGEST_API_TOKEN="replace-with-a-local-secret"
export JWT_SECRET="replace-with-a-random-secret-of-at-least-32-characters"
export INITIAL_ADMIN_USERNAME="admin"
export INITIAL_ADMIN_PASSWORD="replace-with-a-password-of-at-least-12-characters"
export SERVER_PORT=8086
mvn spring-boot:run
```

PowerShell:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
$env:JWT_SECRET = "replace-with-a-random-secret-of-at-least-32-characters"
$env:INITIAL_ADMIN_USERNAME = "admin"
$env:INITIAL_ADMIN_PASSWORD = "replace-with-a-password-of-at-least-12-characters"
$env:SERVER_PORT = "8086"
mvn spring-boot:run
```

If Java 17 and Maven are not installed, build the image and run it directly:

```powershell
docker build -t safe-playground/backend .
docker run --rm -p 8086:8086 `
  -e "INGEST_API_TOKEN=replace-with-a-local-secret" `
  -e "JWT_SECRET=replace-with-a-random-secret-of-at-least-32-characters" `
  -e "INITIAL_ADMIN_USERNAME=admin" `
  -e "INITIAL_ADMIN_PASSWORD=replace-with-a-password-of-at-least-12-characters" `
  -v "${PWD}/data:/app/data" `
  safe-playground/backend
```

The default profile uses a local H2 file database at `./data/playground` and
stores images under `./data/media`. Flyway creates the schema on first startup.
The API listens on `http://localhost:8086` (override with `SERVER_PORT`).

To run the tests:

```bash
mvn test
```

## PostgreSQL

Set `POSTGRES_PASSWORD`, then start the database:

```bash
export POSTGRES_PASSWORD="replace-with-a-local-password"
docker compose up -d postgres
export DATABASE_PASSWORD="$POSTGRES_PASSWORD"
export INGEST_API_TOKEN="replace-with-a-local-secret"
export JWT_SECRET="replace-with-a-random-secret-of-at-least-32-characters"
export INITIAL_ADMIN_USERNAME="admin"
export INITIAL_ADMIN_PASSWORD="replace-with-a-password-of-at-least-12-characters"
mvn spring-boot:run -Dspring-boot.run.profiles=postgres
```

The PostgreSQL options are in this directory's `docker-compose.yml`. The root
stack uses H2 by default so it stays a single command.

## API

- `GET /api/v1/incidents` returns the JSON array expected by the operator app.
- `GET /api/v1/persons` returns pending and trusted persons.
- `POST /api/v1/persons/{id}/confirm` confirms a pending person and returns 204.
- `POST /api/v1/auth/login` accepts `{ "username", "password" }` and returns a
  two-hour bearer token.
- `GET/POST /api/v1/users`, `PATCH /api/v1/users/{id}/enabled` manage accounts;
  only administrators may use them. Passwords are BCrypt-hashed and at least
  12 characters long.
- `GET/POST /api/v1/cameras`, `PUT/DELETE /api/v1/cameras/{id}` manage the camera
  catalog. Deleting a camera with recordings is rejected.
- `GET /api/v1/recordings?cameraId=&from=&to=` returns filtered recordings;
  dates are ISO-8601 instants and `to` is exclusive. `POST/PUT/DELETE
  /api/v1/recordings[/{id}]` manage recording metadata; only administrators can
  mutate the catalog.
- `POST /api/v1/incidents` ingests an event from the CV service. It requires
  `X-Ingest-Token`; configure it with `INGEST_API_TOKEN`.

Set `JWT_SECRET` to a private string with at least 32 characters. Set
`INITIAL_ADMIN_USERNAME` and `INITIAL_ADMIN_PASSWORD` together to bootstrap
the first administrator; password must be at least 12 characters. The
bootstrap account is created only when its username does not exist. There is
no public registration. Account disablement immediately invalidates existing
tokens on their next request.

The ingest JSON accepts `type`, ISO-8601 `occurredAt`, optional `trackId`,
`confidence`, `description`, `personId`, `snapshotBase64`, and
`faceSnapshotBase64`. Images must be JPEG and are limited to 5 MB after base64
decoding. Repeated track/type events within `INGEST_DEDUPLICATION_WINDOW`
(default 30 seconds) return the existing incident rather than creating a
duplicate. A stranger event without `personId` creates a pending person; a
subsequent event can update that person's visit count by supplying its `personId`.

Errors use `{ "code": "...", "message": "..." }`. Allowed browser origins are
configured with `CORS_ALLOWED_ORIGINS` (comma-separated).

## Camera and recording source

The catalog stores camera details and the URL the client should render. For
live MJPEG the camera hub from [`cv_branch`](../cv_branch/README.md) serves
`http://<host>:8090/stream.mjpg`; RTSP URLs work in the desktop app but not in
a browser. The backend does not proxy or transcode video.

Recording entries contain links to video files provided by an external archive
service; the backend does not upload or own the underlying footage.

Face-embedding matching, CV whitelist synchronization, STOMP alerts, and
system-status reporting are not yet implemented. A visitor marked `TRUSTED`
is currently only stored in the backend.
