#imports
from __future__ import annotations

import base64
import os
import signal
import threading
import time
from collections import deque
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

import cv2
from fastapi import FastAPI, Response
from fastapi.responses import StreamingResponse
from ultralytics import YOLO
import torch

# Unbounded cv2/OpenMP thread pools burn several cores per encode; keep them
# in line before anything initialises them.
cv2.setNumThreads(2)

#variables(or smth)
MODEL_PATH = os.environ.get("YOLO_MODEL", "yolo26n.pt")
CAMERA_SOURCE = os.environ.get("CAMERA_SOURCE", "0")
ALERT_CLASSES = {"car", "truck", "bus"}
ALERT_CONF = 0.35
ALERT_COOLDOWN = 5.0
ALERT_DIR = Path(os.environ.get("ALERT_IMAGE_DIR", "alert_images"))
HUMAN_CLASSES = {"person", "human"}
HUMAN_CONF = 0.35
HUMAN_COOLDOWN = 60.0
HUMAN_DIR = Path(os.environ.get("ALERT_IMAGE_DIR", "alert_images"))

# A track is reported once when it appears. If the same track keeps moving for
# longer than this, it is reported again (long enough not to spam the journal).
TRACK_RETRIGGER = float(os.environ.get("ALERT_TRACK_RETRIGGER", "300"))
MAX_PENDING_ALERTS = int(os.environ.get("ALERT_QUEUE_SIZE", "50"))

# CPU guard: on a plain laptop one inference per 30fps frame saturates all
# cores and starves the capture stream. Process only every Nth frame and cap
# the intra-op thread pool (env-tunable).
PROCESS_STRIDE = int(os.environ.get("CV_PROCESS_STRIDE", "4"))
TORCH_THREADS = int(os.environ.get("CV_TORCH_THREADS", "2"))

# YOLO letterboxes every frame to imgsz²; 480 keeps enough detail for people
# in a 1280x720 frame while running much faster on CPU than the 640 default.
INFERENCE_IMGSZ = int(os.environ.get("CV_IMGSZ", "480"))

# Downscale only the *published* MJPEG frame (inference still runs on the
# full frame). 0.75 => 960x540: encodes ~2x faster and streams lighter.
PUBLISH_SCALE = float(os.environ.get("CV_PUBLISH_SCALE", "1.0"))

# latest annotated frame, shared by the detector and the MJPEG endpoint
_latest_jpeg = b""
_frame_seq = 0
_frame_cond = threading.Condition()

# incidents waiting for the backend longpoll
LONGPOLL_TIMEOUT = 60.0
_alerts = deque(maxlen=MAX_PENDING_ALERTS)
_dropped_alerts = 0
_alert_cond = threading.Condition()

_stop = threading.Event()


def _stop_server(signum=None, frame=None):
    _stop.set()
    with _frame_cond:
        _frame_cond.notify_all()
    with _alert_cond:
        _alert_cond.notify_all()


def _install_stop_handler():
    # uvicorn installs its own SIGINT handler before startup; wrap it so the
    # MJPEG/longpoll loops stop before uvicorn waits for open connections.
    if threading.current_thread() is not threading.main_thread():
        return
    for sig in (signal.SIGINT, signal.SIGTERM):
        previous = signal.getsignal(sig)
        def handle(signum, frame, previous=previous):
            _stop_server()
            if callable(previous):
                previous(signum, frame)
        try:
            signal.signal(sig, handle)
        except (ValueError, OSError):
            pass

@asynccontextmanager
async def lifespan(app: FastAPI):
    # one detection loop feeds both alerts and the MJPEG preview
    _install_stop_handler()
    thread = threading.Thread(target=process, daemon=True)
    thread.start()
    yield
    _stop_server()
    thread.join(timeout=2.0)


# <-------------- Dsinkerii put your API stuff here pls pls pls pls
# dsinkerii: yup on it
app = FastAPI(title="cv service", lifespan=lifespan)

_model = None


def get_model() -> YOLO:
    global _model
    if _model is None:
        # Limit intra-op threads: the default (all cores) at ~100% CPU
        # starves the capture stream, the hub and the app.
        torch.set_num_threads(max(1, TORCH_THREADS))
        _model = YOLO(MODEL_PATH) # initialises model
        print(_model.names) # prints dictionary
    return _model


def normalize_source(value):
    # can use several webcams for test, so have to switch between
    value = str(value).strip()
    return int(value) if value.isdigit() else value


def capture_image(source=CAMERA_SOURCE, frame=None, capture_type='ALERT') -> Path | None:
    # well, camera capture
    if frame is None:
        cap = cv2.VideoCapture(normalize_source(source))
        ret, frame = cap.read() # returns a single frame
        cap.release()
        if not ret:
            return None

    l_tm = time.localtime()
    date = f"{l_tm.tm_year}_{l_tm.tm_mon}_{l_tm.tm_mday}_{l_tm.tm_hour}_{l_tm.tm_min}_{l_tm.tm_sec}"
    match capture_type:
        case 'ALERT':
            ALERT_DIR.mkdir(parents=True, exist_ok=True)
            path = ALERT_DIR / f"{date}.jpg"
            cv2.imwrite(str(path), frame) # writes to file(hopefully)
            print("CAUGHT EM!!! KIDNAPPERS!!!!!!")
            return path
        case 'HUMAN':
            HUMAN_DIR.mkdir(parents=True, exist_ok=True)
            path = HUMAN_DIR / f"{date}.jpg"
            cv2.imwrite(str(path), frame) # writes to file(hopefully)
            print("CAUGHT EM!!! UNKNOWNS???!!!")
            return path


def matching_detections(result, classes=ALERT_CLASSES, conf=ALERT_CONF):
    boxes = result.boxes
    if boxes is None:
        return
    names = result.names or {}
    ids = boxes.id
    track_ids = ids.tolist() if ids is not None else [None] * len(boxes.cls)
    for cls, score, track_id in zip(boxes.cls.tolist(), boxes.conf.tolist(), track_ids):
        label = names.get(int(cls))
        # makes sure it's a car and not a toy
        if label in classes and score >= conf:
            yield label, float(score), int(track_id) if track_id is not None else None


def publish(frame) -> None:
    global _latest_jpeg, _frame_seq
    ok, buffer = cv2.imencode(".jpg", frame)
    if not ok:
        return
    with _frame_cond:
        _latest_jpeg = buffer.tobytes()
        _frame_seq += 1
        _frame_cond.notify_all()


def publish_alert(capture_type, label, confidence, snapshot, track_id=None) -> None:
    global _dropped_alerts
    incident_type = 'STRANGER_DETECTED' if capture_type == 'HUMAN' else 'VEHICLE_IN_ZONE'
    try:
        encoded = base64.b64encode(Path(snapshot).read_bytes()).decode("ascii")
    except OSError as exc:
        print(f"[cv] could not read snapshot {snapshot}: {exc}", flush=True)
        return

    payload = {
        "type": incident_type,
        "occurredAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "trackId": str(track_id) if track_id is not None else None,
        "confidence": round(confidence, 3),
        # Leave description empty: the backend fills the localized default.
        "description": None,
        "personId": None,
        "snapshotBase64": encoded,
        # The backend saves this as the visitor's photo. There is no face crop
        # yet, so the annotated frame is the best available image.
        "faceSnapshotBase64": encoded if capture_type == 'HUMAN' else None,
    }
    with _alert_cond:
        if len(_alerts) >= MAX_PENDING_ALERTS:
            _dropped_alerts += 1
        _alerts.append(payload)
        _alert_cond.notify_all()
    print(
        f"[cv] queued {incident_type} label={label} track={track_id} "
        f"conf={confidence:.2f} bytes={len(encoded)} queue={len(_alerts)}",
        flush=True,
    )


def detect(source=CAMERA_SOURCE):
    # checks for dangerous objects and tracks them so one car/person is not
    # reported on every frame. ByteTrack keeps stable IDs across frames.
    model = get_model()
    try:
        results = model.track(
            source=normalize_source(source),
            stream=True,
            persist=True,
            tracker="bytetrack.yaml",
            show=False,
            stream_buffer=False,
            verbose=False,
            vid_stride=PROCESS_STRIDE,
            imgsz=INFERENCE_IMGSZ,
        )
    except Exception as exc:
        # Older Ultralytics builds may not expose track(); prediction still
        # works, it just loses stable IDs (and therefore per-track dedupe).
        print(f"[cv] tracking unavailable ({exc}); falling back to predict", flush=True)
        results = model.predict(
            source=normalize_source(source),
            stream=True,
            show=False,
            stream_buffer=False,
            verbose=False,
            vid_stride=PROCESS_STRIDE,
            imgsz=INFERENCE_IMGSZ,
        )
    try:
        for result in results:
            if _stop.is_set():
                break
            annotated = result.plot()  # rectangles + class names
            if PUBLISH_SCALE < 1.0:
                annotated = cv2.resize(
                    annotated, None, fx=PUBLISH_SCALE, fy=PUBLISH_SCALE,
                    interpolation=cv2.INTER_AREA,
                )
            publish(annotated)
            for label, confidence, track_id in matching_detections(
                    result, ALERT_CLASSES, ALERT_CONF):
                yield label, confidence, annotated, track_id, 'ALERT'
            # same for humans, detect humans
            for label, confidence, track_id in matching_detections(
                    result, HUMAN_CLASSES, HUMAN_CONF):
                yield label, confidence, annotated, track_id, 'HUMAN'
    finally:
        close = getattr(results, "close", None)
        if callable(close):
            close()


def process(source=CAMERA_SOURCE, conf=ALERT_CONF, classes=ALERT_CLASSES):
    last_alert = 0.0
    last_human = 0.0
    last_track: dict[str, float] = {}

    while not _stop.is_set():
        try:
            for label, confidence, frame, track_id, capture_type in detect(source):
                if _stop.is_set():
                    break
                now = time.monotonic()
                is_human = capture_type == 'HUMAN'
                if is_human:
                    if now - last_human < HUMAN_COOLDOWN:
                        continue
                elif now - last_alert < ALERT_COOLDOWN:
                    continue

                # Per-track gate: report a given object once, not every frame.
                track_key = f"{capture_type}:{track_id}" if track_id is not None else None
                if track_key is not None:
                    previous = last_track.get(track_key, 0.0)
                    if now - previous < TRACK_RETRIGGER:
                        continue

                if is_human:
                    last_human = now
                else:
                    last_alert = now

                snapshot = capture_image(frame=frame, capture_type=capture_type)
                if snapshot is not None and snapshot.exists():
                    publish_alert(capture_type, label, confidence, snapshot, track_id)
                    if track_key is not None:
                        last_track[track_key] = now
                    # Keep the dictionary bounded on long-running deployments.
                    if len(last_track) > 500:
                        cutoff = now - TRACK_RETRIGGER
                        last_track = {
                            key: seen for key, seen in last_track.items() if seen >= cutoff
                        }
                print(f"[cv] {label} ({confidence:.2f}) track={track_id} -> {snapshot}",
                      flush=True)
        except Exception as exc:
            if _stop.is_set():
                break
            print(f"[cv] detection loop failed: {exc}; retrying in 3s", flush=True)
            time.sleep(3.0)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": MODEL_PATH,
        "source": str(CAMERA_SOURCE),
        "model_loaded": _model is not None,
        "pending_alerts": len(_alerts),
        "dropped_alerts": _dropped_alerts,
    }


@app.get("/alerts/longpoll")
def longpoll(timeout: float = LONGPOLL_TIMEOUT):
    # The backend asks for slightly more than the service-side default. Cap it
    # so a client cannot hold a worker forever.
    wait_seconds = max(0.0, min(float(timeout), LONGPOLL_TIMEOUT))
    deadline = time.monotonic() + wait_seconds
    with _alert_cond:
        while not _alerts and not _stop.is_set():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            _alert_cond.wait(remaining)
        if _alerts:
            return _alerts.popleft()
    return Response(status_code=204)


@app.get("/stream.mjpg")
def stream():
    def frames():
        last = -1
        while not _stop.is_set():
            with _frame_cond:
                _frame_cond.wait_for(lambda: _frame_seq != last or _stop.is_set(), timeout=2.0)
                jpeg, last = _latest_jpeg, _frame_seq
            if _stop.is_set():
                break
            if not jpeg:
                continue
            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n"
                b"Content-Length: " + str(len(jpeg)).encode() + b"\r\n\r\n"
                + jpeg + b"\r\n"
            )

    return StreamingResponse(
        frames(), media_type="multipart/x-mixed-replace; boundary=frame"
    )


if __name__ == "__main__":
    import uvicorn

    # 6532 falls into a Windows excluded port range; default to a free port.
    uvicorn.run(
        app, host="0.0.0.0", port=int(os.environ.get("CV_SERVICE_PORT", "6545"))
    )
