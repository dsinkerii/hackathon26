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
uvicorn cv_service:app --host 0.0.0.0 --port 6532
```

The default source is webcam `0`. Override it with `CAMERA_SOURCE` — an
MJPEG/RTSP URL, a video path, or another webcam index:

```powershell
$env:CAMERA_SOURCE = "http://127.0.0.1:8090/stream.mjpg"
uvicorn cv_service:app --host 0.0.0.0 --port 6532
```

`cv_service.py` exposes a FastAPI `app` with `/health`, `/stream.mjpg`, and
`/alerts/longpoll`. The MJPEG endpoint serves the annotated preview (rectangles
+ class names), so no OpenCV window is needed. The detection pipeline is
available as `detect()` (yields label, confidence and frame) and `process()`
(saves a JPEG under `alert_images/` when a `car`, `truck`, or `bus` is detected,
at most once every 5 seconds).

`GET /alerts/longpoll` is for the backend. It waits up to 60 seconds and returns
`204 No Content` if nothing happens. When an ALERT or HUMAN screenshot is saved
it returns immediately with the ingest JSON: `type`, `occurredAt`, `trackId`,
`confidence`, `description`, `personId`, `snapshotBase64`,
`faceSnapshotBase64`. ALERT maps to `VEHICLE_IN_ZONE`; HUMAN maps to
`STRANGER_DETECTED`.

Only one process can open the webcam. If `camera_hub.py` is already using
`/dev/video0`, point `CAMERA_SOURCE` at the hub URL instead of `0`.

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
