# Safe Playground / PlayGuard AI

Operator console for a monitored playground: a Flutter web app, a Spring Boot
backend, and a single-process MJPEG camera hub shared by the UI and the YOLO
detector.

The whole stack runs with Docker. **You do not need Flutter, Java, Maven,
Python or Node installed on the host** to use it — only Docker.

## Quick start (fresh machine)

1. Install **Docker Desktop** (Windows/macOS) or Docker Engine + Compose
   (Linux).
2. Clone the repository and enter it.
3. Start the stack:

   **Windows (PowerShell):**
   ```powershell
   .\start.ps1 -Demo
   ```
   If PowerShell blocks the script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\start.ps1 -Demo
   ```

   **Linux/macOS:**
   ```bash
   ./start.sh --demo
   ```

   Or without the helper scripts:
   ```bash
   docker compose --profile demo up --build -d
   ```

4. Open <http://localhost:5173> and sign in with:

   | | |
   | --- | --- |
   | Username | `playground` |
   | Password | `playground-demo` |

The `demo` profile generates a synthetic 720p moving test pattern, so video
works even on a machine with no webcam. Change the credentials in `.env`
before sharing the stack with anyone.

> **First run is slow.** Docker pulls a ~6 GB Flutter build image and compiles
> the app. Expect 5–15 minutes and ~8 GB of disk. Subsequent starts take
> seconds because every layer is cached.

## Using a real camera

Containers do not get host webcams by default (especially on Windows), so the
camera hub runs natively. It owns the device once and republishes it as MJPEG
for both the UI and OpenCV.

```powershell
cd cv_branch
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python camera_hub.py --source 0
```

```bash
# Linux/macOS equivalent
cd cv_branch
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python camera_hub.py --source 0
```

Then start the app **without** the demo profile:

```powershell
.\start.ps1
# or: docker compose up --build -d
```

In the app open **Камеры**, create a camera with stream URL:

```
http://localhost:8090/stream.mjpg
```

The MJPEG stream is also readable directly by OpenCV and VLC. Check it at
<http://localhost:8090/>.

### Camera notes

- Only **one** process may open the webcam. Do not run a second capture tool
  against `/dev/video0` (or `--source 0` on Windows) while the hub is running.
- If the image is black, check the privacy shutter and the lights. In a dark
  room the camera lowers its frame rate and YOLO accuracy drops.
- If the device cannot be opened with the default format, try
  `--fourcc ""` or a different index (`--source 1`).
- `--source` also accepts a video file, an RTSP URL, or another MJPEG URL.

## Ports

| Service | Host URL | Notes |
| --- | --- | --- |
| Operator app | <http://localhost:5173> | nginx, serves the release web build |
| Backend API | <http://localhost:8086> | proxied by the web app at `/api` and `/media` |
| Camera hub | <http://localhost:8090> | only with a real camera or `--profile demo` |
| PostgreSQL | — | not used by default; the backend persists H2 under a volume |

The web app calls the API on its own origin; nginx forwards `/api/` and
`/media/` to the backend. That means the app also works when opened from
another machine on the LAN (`http://<host-ip>:5173`), with no rebuild and no
CORS configuration.

Camera URLs are resolved by the **browser**, so `localhost:8090` only works on
the machine running Docker. To watch from a phone or another PC, register the
camera with the host's LAN address instead, e.g.
`http://192.168.1.50:8090/stream.mjpg`, and allow the port through the host
firewall.

The compose defaults bind ports to all interfaces. This is a development/demo
setup: change the secrets and do not expose it to the internet.

## Configuration

`start.ps1` / `start.sh` copy `.env.example` to `.env` on first run. Edit
`.env` to change ports, secrets, or the bootstrap administrator:

| Variable | Default | Purpose |
| --- | --- | --- |
| `WEB_PORT` | `5173` | host port of the operator app |
| `BACKEND_PORT` | `8086` | host port of the backend |
| `CAMERA_PORT` | `8090` | host port of the camera hub (demo profile) |
| `JWT_SECRET` | dev value | **must be ≥ 32 characters** |
| `INGEST_API_TOKEN` | dev value | token for `POST /api/v1/incidents` |
| `INITIAL_ADMIN_USERNAME` | `playground` | created only on first start |
| `INITIAL_ADMIN_PASSWORD` | `playground-demo` | **must be ≥ 12 characters** |
| `DEMO_CAMERA_URL` | `http://localhost:8090/stream.mjpg` | camera entry seeded in demo mode |

The bootstrap account is created only when its username does not exist.
Changing `INITIAL_ADMIN_PASSWORD` later has no effect on an existing database.

### Reset everything

```bash
docker compose --profile demo down -v
```

This deletes the H2 database, uploaded snapshots, and the seeded camera. It
does not delete the Docker images, so the next start is fast.

## Rebuilding after code changes

| Change | Command |
| --- | --- |
| Flutter app | `docker compose build web && docker compose up -d web` |
| Backend | `docker compose build backend && docker compose up -d backend` |
| Camera hub | `docker compose --profile demo build camera && docker compose --profile demo up -d camera` |
| Everything | `docker compose --profile demo up --build -d` |

Follow logs with `docker compose logs -f web backend`.

## Optional: YOLO detector

The detector opens webcam `0` by default. Run it on the host (CPU inference
needs no GPU):

```powershell
cd cv_branch
.\.venv\Scripts\Activate.ps1
pip install -r requirements-cv.txt
uvicorn cv_service:app --host 0.0.0.0 --port 6532
```

`cv_service.py` exposes a FastAPI app (`app`) with `/health`,
`/stream.mjpg`, and `/alerts/longpoll`. The MJPEG endpoint shows the annotated
preview (rectangles + class names) in a browser or the Flutter app.
`/alerts/longpoll` blocks up to 60 seconds and returns the incident JSON
immediately when an alert is saved (`204` on timeout). `CAMERA_SOURCE`
overrides the default source and accepts an MJPEG/RTSP URL, a video path, or a
webcam index (`0`, `1`, ...). Detection is available through `detect()` and
`process()` for the API to call.

## Native development (optional)

Docker is the supported way to run the stack. If you are changing UI code and
want hot reload, install Flutter and run the app against the containerised
backend:

```bash
cd operator-app
flutter pub get
flutter run -d chrome --web-port 5173 \
  --dart-define=API_BASE_URL=http://localhost:8086
```

Run just the backend and database, then the app natively:

```bash
docker compose up -d backend
docker compose stop web          # free port 5173 for the dev server
cd operator-app && flutter run -d chrome --web-port 5173 \
  --dart-define=API_BASE_URL=http://localhost:8086
```

The backend's default CORS allow-list contains `http://localhost:5173`; use a
different port only if you also add it to `CORS_ALLOWED_ORIGINS`.

Backend-only development (Java 17 + Maven) is described in
[`backend/README.md`](backend/README.md).

## End-to-end checks

```bash
curl http://localhost:8086/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"playground","password":"playground-demo"}'

curl http://localhost:8090/health
# {"ready": true, "source": "...", "fps": 26.8, "error": null}
```

The camera hub endpoints are documented in
[`cv_branch/README.md`](cv_branch/README.md).

## Troubleshooting

**A port is already in use.** Another process owns 5173/8086/8090 (often a
previous native run). Stop it, or change `WEB_PORT`, `BACKEND_PORT`, or
`CAMERA_PORT` in `.env`. If you change `CAMERA_PORT`, also update
`DEMO_CAMERA_URL`.

**The demo camera entry is missing.** `seed-camera` only runs in the `demo`
profile and is idempotent. Check it with
`docker compose --profile demo logs seed-camera`. A camera whose URL is
`http://0.0.0.0:8090/...` is rewritten by the app to `127.0.0.1`, but
`localhost` is the clearest choice.

**Login says the credentials are wrong.** The bootstrap account exists only
after the first successful start, and only with the values present at that
time. Reset with `docker compose down -v`, then start again.

**The video panel says it cannot open the stream.** Verify
<http://localhost:8090/health> from the *browser machine*. The browser must be
able to reach the URL stored in the camera entry — inside a container the
hostname would be different, which is why seeded entries use `localhost`.

**Windows firewall prompts.** Allow Docker Desktop on private networks if you
want to open the app from a phone or another PC.

**The web build is stale.** `docker compose up -d` does not rebuild images.
Use the commands in [Rebuilding after code changes](#rebuilding-after-code-changes).

## Repository layout

```
backend/        Spring Boot API (H2 by default, PostgreSQL profile optional)
operator-app/   Flutter web client (served by nginx in the container)
cv_branch/      MJPEG camera hub + YOLO detector
scripts/        one-shot helpers (demo camera seeding)
docker-compose.yml
start.ps1 / start.sh
```
