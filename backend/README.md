# Safe Playground Backend

Spring Boot REST backend for the Flutter operator app. Requires Java 17.

## Local run

From this directory:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
$env:JWT_SECRET = "replace-with-a-random-secret-of-at-least-32-characters"
$env:INITIAL_ADMIN_USERNAME = "admin"
$env:INITIAL_ADMIN_PASSWORD = "replace-with-a-password-of-at-least-12-characters"
mvn spring-boot:run
```

If Java 17 and Maven are not installed locally, run Maven in a container from
this directory instead:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
$env:JWT_SECRET = "replace-with-a-random-secret-of-at-least-32-characters"
$env:INITIAL_ADMIN_USERNAME = "admin"
$env:INITIAL_ADMIN_PASSWORD = "replace-with-a-password-of-at-least-12-characters"
docker run --rm -p 8080:8080 `
  -e "INGEST_API_TOKEN=$env:INGEST_API_TOKEN" `
  -e "JWT_SECRET=$env:JWT_SECRET" `
  -e "INITIAL_ADMIN_USERNAME=$env:INITIAL_ADMIN_USERNAME" `
  -e "INITIAL_ADMIN_PASSWORD=$env:INITIAL_ADMIN_PASSWORD" `
  -v "${PWD}:/workspace" -w /workspace `
  maven:3.9-eclipse-temurin-17 mvn spring-boot:run
```

The default profile uses a local H2 file database at `./data/playground` and
stores images under `./data/media`. Flyway creates the schema on first startup.
The API listens on `http://localhost:8080`.

To run the tests:

```powershell
mvn test
```

## PostgreSQL

Set `POSTGRES_PASSWORD`, then start the database:

```powershell
$env:POSTGRES_PASSWORD = "replace-with-a-local-password"
docker compose up -d postgres
$env:DATABASE_PASSWORD = $env:POSTGRES_PASSWORD
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
$env:JWT_SECRET = "replace-with-a-random-secret-of-at-least-32-characters"
$env:INITIAL_ADMIN_USERNAME = "admin"
$env:INITIAL_ADMIN_PASSWORD = "replace-with-a-password-of-at-least-12-characters"
mvn spring-boot:run "-Dspring-boot.run.profiles=postgres"
```

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

The catalog stores camera details and HTTP(S) links to video files provided by
an external camera/archive service. It does not upload, transcode, or retain
the video itself. The player loads the supplied URL directly, so the archive
host must allow browser playback (including CORS where applicable). Live
streaming and physical camera integration remain separate work.

Face-embedding matching, CV whitelist synchronization, STOMP alerts, and
system-status reporting are not yet implemented. A visitor marked `TRUSTED`
is currently only stored in the backend.
