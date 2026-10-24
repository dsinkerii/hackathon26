# Safe Playground Backend

Spring Boot REST backend for the Flutter operator app. Requires Java 17.

## Local run

From this directory:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
mvn spring-boot:run
```

If Java 17 and Maven are not installed locally, run Maven in a container from
this directory instead:

```powershell
$env:INGEST_API_TOKEN = "replace-with-a-local-secret"
docker run --rm -p 8080:8080 `
  -e "INGEST_API_TOKEN=$env:INGEST_API_TOKEN" `
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
mvn spring-boot:run "-Dspring-boot.run.profiles=postgres"
```

## API

- `GET /api/v1/incidents` returns the JSON array expected by the operator app.
- `GET /api/v1/persons` returns pending and trusted persons.
- `POST /api/v1/persons/{id}/confirm` confirms a pending person and returns 204.
- `POST /api/v1/incidents` ingests an event from the CV service. It requires
  `X-Ingest-Token`; configure it with `INGEST_API_TOKEN`.

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

This MVP persists incidents and visitor statuses and keeps the existing Flutter
REST contract. It does not yet perform face-embedding matching, synchronize
the whitelist with the CV service, publish STOMP alerts, expose system status,
or provide video recordings. A person marked `TRUSTED` is currently only stored
in the backend; CV recognition must not be considered updated until whitelist
synchronization is implemented and verified.
