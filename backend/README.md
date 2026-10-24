# Safe Playground Backend

Spring Boot 3.5.6 backend (Java 21) for the Flutter operator app: каркас
`ru.playground` (миграции по vendor: `db/migration/h2|postgresql`) плюс
перенесённые MVP-слои `com.playground.security` (ingest, SSE-алерты, журнал,
демо-сидер; их схема добавляется миграцией `db/migration/legacy/V2__mvp_persons.sql`).

## Local run

From this directory:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
mvn spring-boot:run
```

If Java 21 and Maven are not installed locally, run Maven in a container from
this directory instead:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
docker run --rm -p 8080:8080 `
  -e "INGEST_API_TOKEN=$env:INGEST_API_TOKEN" `
  -v "${PWD}:/workspace" -w /workspace `
  maven:3.9-eclipse-temurin-21 mvn spring-boot:run
```

To run the tests:

```powershell
mvn test
```

The default profile is `h2` (file database at `./data/playground`, images under
`./data/media`). The H2 console is enabled at `/h2-console` in this profile.
Startup applies vendor migrations (H2/PostgreSQL) plus the legacy MVP schema.

Additional environment variables:
- `DEMO_MODE=true` enables `POST /api/v1/demo/reset` (seeded demo dataset),
- `CORS_ALLOWED_ORIGINS` — comma-separated browser origins of the operator console,
- `INGEST_DEDUPLICATION_WINDOW` — repeated track/type ingest window (default `30s`).

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
mvn spring-boot:run "-Dspring-boot.run.profiles=postgres"
```

## API

- `GET /api/v1/incidents` returns the JSON array expected by the operator app.
- `GET /api/v1/persons` returns pending and trusted persons.
- `POST /api/v1/persons/{id}/confirm` confirms a pending person and returns 204.
- `GET /api/v1/alerts/stream` — Server-Sent Events feed. Every created incident
  is pushed as an `alert` event with the same JSON shape as `GET /incidents`;
  comments (`: heartbeat`) arrive every 15 s. Smoke test: `curl -N http://localhost:8080/api/v1/alerts/stream`.
- `POST /api/v1/incidents` ingests an event from the CV service. It requires
  `X-Ingest-Token`; configure it with `INGEST_API_TOKEN`.
- `POST /api/v1/demo/reset` — demo helper, exists only when `DEMO_MODE=true`
  (`app.demo.enabled`). Wipes the journals and seeds a small dataset.

The ingest JSON accepts `type`, ISO-8601 `occurredAt`, optional `trackId`,
`confidence`, `description`, `personId`, `snapshotBase64`, and
`faceSnapshotBase64`. Images must be JPEG and are limited to 5 MB after base64
decoding. Repeated track/type events within `INGEST_DEDUPLICATION_WINDOW`
(default 30 seconds) return the existing incident rather than creating a
duplicate. A stranger event without `personId` creates a pending person; a
subsequent event can update that person's visit count by supplying its `personId`.

Errors use `{ "code": "...", "message": "..." }`. Allowed browser origins are
configured with `CORS_ALLOWED_ORIGINS` (comma-separated).

## MVP scope and follow-up

This MVP persists incidents and visitor statuses, pushes alerts to the operator
console over SSE, and keeps the existing Flutter REST contract. It does not yet
perform face-embedding matching, synchronize the whitelist with the CV service,
or provide video recordings. A person marked `TRUSTED` is currently only stored
in the backend; CV recognition must not be considered updated until whitelist
synchronization is implemented and verified.
