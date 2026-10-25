#imports
from __future__ import annotations

import os
import threading
import time
from contextlib import asynccontextmanager
from pathlib import Path

import cv2
from fastapi import FastAPI
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

@asynccontextmanager
async def lifespan(app: FastAPI):
    # one detection loop feeds both alerts and the MJPEG preview
    threading.Thread(target=process, daemon=True).start()
    yield


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
    for label, confidence, frame in detect(source):
        now = time.monotonic()
        if now - last_alert < ALERT_COOLDOWN:
            continue
        last_alert = now
        snapshot = capture_image(frame=frame)
        print("CHILD SAFETY ALERT or smth idk they don't pay me")
        print(f"[cv] {label} ({confidence:.2f}) -> {snapshot}")


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_PATH, "source": str(CAMERA_SOURCE)}


@app.get("/stream.mjpg")
def stream():
    def frames():
        last = -1
        while True:
            with _frame_cond:
                _frame_cond.wait_for(lambda: _frame_seq != last, timeout=2.0)
                jpeg, last = _latest_jpeg, _frame_seq
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
