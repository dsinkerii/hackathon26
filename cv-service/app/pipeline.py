"""Real video pipeline: OpenCV frame loop + YOLO tracking + zone logic.

Heavy dependencies (`ultralytics`, `opencv-python`, see requirements-cv.txt)
are imported lazily, so the simulator mode never requires them.
"""
from __future__ import annotations

import base64
import time
from datetime import datetime, timezone

from .zone import contains, scale

# COCO classes handled by the MVP: person=0, car=2, motorcycle=3, truck=7.
PERSON_CLASS = 0
VEHICLE_CLASSES = (2, 3, 7)
TRACKED_CLASSES = [PERSON_CLASS, *VEHICLE_CLASSES]

VEHICLE_EVENT = "CAR_ON_PLAYGROUND"
STRANGER_EVENT = "STRANGER_DETECTED"


def run(settings, publish) -> None:
    import cv2  # noqa: PLC0415 — heavy import, deferred until the real mode
    from ultralytics import YOLO  # noqa: PLC0415

    capture = _open_capture(cv2, settings)
    if capture is None or not capture.isOpened():
        raise RuntimeError(f"Cannot open video source for mode '{settings.mode}'.")

    model = YOLO("yolov8n.pt")
    cooldown: dict[tuple[str, str], float] = {}

    print(f"[pipeline] Running on source mode '{settings.mode}'. Ctrl+C to stop.")
    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                if settings.mode == "video":
                    capture.set(1, 0)  # rewind the demo clip and keep looping
                    continue
                break

            height, width = frame.shape[:2]
            zone = scale(settings.polygon, width, height)
            results = model.track(
                frame,
                persist=True,
                classes=TRACKED_CLASSES,
                conf=settings.detection_confidence,
                verbose=False,
            )
            now = time.time()

            for box in _boxes(results):
                track_id = box.track_id
                kind = VEHICLE_EVENT if box.cls in VEHICLE_CLASSES else STRANGER_EVENT
                if not contains(zone, box.cx, box.cy):
                    continue
                key = (track_id, kind)
                last = cooldown.get(key)
                if last is not None and now - last < settings.cooldown_seconds:
                    continue

                cooldown[key] = now
                event = {
                    "type": kind,
                    "occurredAt": datetime.now(timezone.utc).isoformat(),
                    "trackId": track_id,
                    "confidence": round(box.conf, 2),
                    "snapshotBase64": _encode_jpeg(cv2, frame),
                }
                publish(event)
    except KeyboardInterrupt:
        print("[pipeline] Stopped.")
    finally:
        capture.release()


def _open_capture(cv2, settings):
    if settings.mode == "camera":
        return cv2.VideoCapture(settings.camera_index)
    return cv2.VideoCapture(settings.video_path)


def _boxes(results):
    """Flattens YOLO results into lightweight (id, class, conf, center) tuples."""
    for result in results:
        boxes = result.boxes
        for i in range(len(boxes)):
            xywh = boxes.xywh[i].tolist()
            cls = int(boxes.cls[i].item())
            conf = float(boxes.conf[i].item())
            raw_id = boxes.id[i].item() if boxes.id is not None else -1
            yield _Box(
                track_id=f"track-{int(raw_id)}" if raw_id >= 0 else "track-unknown",
                cls=cls,
                conf=conf,
                cx=xywh[0],
                cy=xywh[1],
            )


class _Box:
    __slots__ = ("track_id", "cls", "conf", "cx", "cy")

    def __init__(self, track_id: str, cls: int, conf: float, cx: float, cy: float):
        self.track_id = track_id
        self.cls = cls
        self.conf = conf
        self.cx = cx
        self.cy = cy


def _encode_jpeg(cv2, frame) -> str:
    ok, buffer = cv2.imencode(".jpg", frame)
    return base64.b64encode(buffer).decode("ascii") if ok else ""
