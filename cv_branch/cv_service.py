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

# latest annotated frame, shared by the detector and the MJPEG endpoint
_latest_jpeg = b""
_frame_seq = 0
_frame_cond = threading.Condition()

# incidents waiting for the backend longpoll
LONGPOLL_TIMEOUT = 60.0
_alerts = deque()
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


def matching_detections(result, classes=ALERT_CLASSES, conf=ALERT_CONF, capture_type='ALERT'):
    boxes = result.boxes
    if boxes is None:
        return
    names = result.names or {}
    for cls, score in zip(boxes.cls.tolist(), boxes.conf.tolist()):
        label = names.get(int(cls))
        # makes sure it's a car and not a toy
        if label in classes and score >= conf:
            yield label, float(score)


def publish(frame) -> None:
    global _latest_jpeg, _frame_seq
    ok, buffer = cv2.imencode(".jpg", frame)
    if not ok:
        return
    with _frame_cond:
        _latest_jpeg = buffer.tobytes()
        _frame_seq += 1
        _frame_cond.notify_all()


def publish_alert(capture_type, label, confidence, snapshot) -> None:
    incident_type = 'STRANGER_DETECTED' if capture_type == 'HUMAN' else 'VEHICLE_IN_ZONE'
    payload = {
        "type": incident_type,
        "occurredAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "trackId": None,
        "confidence": round(confidence, 3),
        "description": f"Detected {label} ({capture_type})",
        "personId": None,
        "faceSnapshotBase64": None,
    }
    with _alert_cond:
        _alerts.append(payload)
        _alert_cond.notify_all()


def detect(source=CAMERA_SOURCE):
    # checks for dangerous objects
    #test camera: 'http://109.206.96.58:8080/cam_1.cgi'
    results = get_model().predict(
        source=normalize_source(source),
        stream=True,
        show=False,
        stream_buffer=False,
    )
    try:
        for result in results:
            if _stop.is_set():
                break
            publish(result.plot()) # rectangles + class names
            for label, confidence in matching_detections(result, ALERT_CLASSES, ALERT_CONF, 'ALERT'):
                yield label, confidence, result.orig_img
            # same for humans, detect humans
            for label, confidence in matching_detections(result, HUMAN_CLASSES, HUMAN_CONF, 'HUMAN'):
                yield label, confidence, result.orig_img
    finally:
        close = getattr(results, "close", None)
        if callable(close):
            close()


def process(source=CAMERA_SOURCE, conf=ALERT_CONF, classes=ALERT_CLASSES):
    last_alert = 0.0
    last_human = 0.0
    for label, confidence, frame in detect(source):
        if _stop.is_set():
            break
        now = time.monotonic()
        if label in HUMAN_CLASSES:
            if now - last_human < HUMAN_COOLDOWN:
                continue
            last_human = now
            capture_type = 'HUMAN'
        else:
            if now - last_alert < ALERT_COOLDOWN:
                continue
            last_alert = now
            capture_type = 'ALERT'
        snapshot = capture_image(frame=frame, capture_type=capture_type)
        if snapshot is not None and snapshot.exists():
            publish_alert(capture_type, label, confidence, snapshot)
        print("CHILD SAFETY ALERT or smth idk they don't pay me")
        print(f"[cv] {label} ({confidence:.2f}) -> {snapshot}")


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_PATH, "source": str(CAMERA_SOURCE)}


@app.get("/alerts/longpoll")
def longpoll():
    deadline = time.monotonic() + LONGPOLL_TIMEOUT
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

    uvicorn.run(app, host="0.0.0.0", port=6532)
