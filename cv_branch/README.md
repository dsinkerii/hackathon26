# CV service

## Camera hub

A webcam can only be opened by **one** process, so capture lives in a single
place: `camera_hub.py`. It grabs frames once and republishes them as MJPEG over
HTTP for both the operator app and the YOLO detector.

### Install (host)

Python 3.10+ is enough for the hub.

Windows (PowerShell):

```powershell
cd cv_branch
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Linux/macOS:

```bash
cd cv_branch
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Run

```powershell
python camera_hub.py --source 0
```

| Endpoint | Purpose |
| --- | --- |
| `GET /stream.mjpg` | MJPEG (`multipart/x-mixed-replace`) — browsers, `cv2`, VLC |
| `GET /snapshot.jpg` | latest frame as a single JPEG |
| `GET /health` | JSON: `ready`, `fps`, `error` |
| `GET /` | small HTML page that shows the stream |

Options: `--source` (camera index, device path, RTSP URL, MJPEG URL, or video
file), `--host`, `--port`, `--width`/`--height`, `--fps`, `--quality`,
`--fourcc`, `--loop`.

Quick check:

```powershell
curl http://127.0.0.1:8090/health
start http://127.0.0.1:8090/
```

If `/health` reports a low `fps` and the picture is black, the lens is covered,
the privacy shutter is closed, or the room is dark — the camera slows its frame
rate to compensate. If the device refuses to open, try `--fourcc ""`, a
different index (`--source 1`), or a different backend/capture tool.

### Docker demo (no webcam)

The root `docker-compose.yml` can run a synthetic 720p stream instead:

```bash
docker compose --profile demo up --build -d camera
```

It serves `http://localhost:8090/stream.mjpg` from a generated test pattern.
That is what the `demo` profile uses; it is not a substitute for a real camera.

## Detector

```powershell
pip install -r requirements-cv.txt
python cv_service.py http://127.0.0.1:8090/stream.mjpg
```

Without a source argument it defaults to
`http://127.0.0.1:8090/stream.mjpg`. The positional source can also be a
webcam index (`0`, `1`, ...), an RTSP/MJPEG URL, or a video file:

```powershell
python cv_service.py 0
```

When a `car`, `truck`, or `bus` is detected above `--conf`, the detector saves
a JPEG snapshot under `alert_images/` and prints an alert. Snapshots are
rate-limited by `--alert-cooldown` (default 5 s) so the stream is not blocked.

Flags: `--model`, `--conf`, `--classes`, `--alert-dir`, `--alert-cooldown`,
`--no-show`, `--save`. To also push alerts to the backend, point it at
`POST /api/v1/incidents`:

```powershell
$env:INGEST_URL = "http://127.0.0.1:8086/api/v1/incidents"
$env:INGEST_API_TOKEN = "local-ingest-token"
python cv_service.py
```

`--incident-type` selects the type sent (default `VEHICLE_IN_ZONE`).

The detector reads the same hub, so it does not compete with the UI for the
device. `CAMERA_SOURCE=...` also works instead of the positional argument.
Do not point `cv_service.py 0` at a webcam while `camera_hub.py` is already
using it — a device can only be opened by one process.

## Operator app

Add a camera whose stream URL is:

```
http://localhost:8090/stream.mjpg
```

On web the app renders it with a plain `<img>`; on Linux/Windows/mobile
`media_kit` plays the same URL. RTSP still works on desktop but not in a
browser — browsers cannot play RTSP at all.

`0.0.0.0` must not appear in the URL. It is a bind address, and Chrome rejects
it for image subresources; the app rewrites it to `127.0.0.1`, but
`localhost` is clearer.

## MediaMTX alternative

If you need RTSP, keep publishing with ffmpeg and let the hub read it:

```bash
python camera_hub.py --source rtsp://127.0.0.1:8554/cam
```

Do not run a second process against `/dev/video0` at the same time.
