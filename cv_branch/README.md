# CV service

## Camera hub

A webcam can only be opened by **one** process, so capture lives in a single
place: `camera_hub.py`. It grabs frames once and republishes them as MJPEG over
HTTP for both the operator app and the detector.

```bash
cd cv_branch
source .venv/bin/activate
python camera_hub.py --source 0
```

| Endpoint | Purpose |
| --- | --- |
| `GET /stream.mjpg` | MJPEG (`multipart/x-mixed-replace`) — browsers, `cv2`, VLC |
| `GET /snapshot.jpg` | latest frame as a single JPEG |
| `GET /health` | JSON: `ready`, `fps`, `error` |
| `GET /` | small HTML page that shows the stream |

Options: `--source` (camera index, device path, RTSP URL or video file),
`--width`/`--height`, `--fps`, `--quality`, `--fourcc`, `--port`, `--loop`.

Quick check:

```bash
curl http://127.0.0.1:8090/health
xdg-open http://127.0.0.1:8090/   # or open it in a browser
```

If `/health` reports a low `fps` and the picture is black, the lens is covered
or the privacy shutter (Logitech BRIO) is closed — the camera slows its frame
rate in the dark to compensate.

## Detector

```bash
python cv_service.py
# or point it somewhere else:
CAMERA_SOURCE=http://127.0.0.1:8090/stream.mjpg python cv_service.py
```

The detector reads the same hub, so it no longer competes with the UI for the
device.

## Operator app

Add a camera whose stream URL is:

```
http://127.0.0.1:8090/stream.mjpg
```

On web the app renders it with a plain `<img>`; on Linux/Windows/mobile
`media_kit` plays the same URL. RTSP still works on desktop but not in a
browser — browsers cannot play RTSP at all.

## MediaMTX alternative

If you need RTSP, keep publishing with ffmpeg and let the hub read it:

```bash
python camera_hub.py --source rtsp://127.0.0.1:8554/cam
```

Do not run a second process against `/dev/video0` at the same time.
