# imports
from __future__ import annotations

import argparse
import base64
import json
import os
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import cv2
from ultralytics import YOLO

# variables (or smth)
DEFAULT_SOURCE = os.environ.get("CAMERA_SOURCE", "http://127.0.0.1:8090/stream.mjpg")
DEFAULT_MODEL = os.environ.get("YOLO_MODEL", "yolo26n.pt")
DEFAULT_CLASSES = os.environ.get("ALERT_CLASSES", "car,truck,bus")
DEFAULT_ALERT_DIR = os.environ.get("ALERT_IMAGE_DIR", "alert_images")
DEFAULT_INGEST_URL = os.environ.get("INGEST_URL", "")
DEFAULT_INGEST_TOKEN = os.environ.get("INGEST_API_TOKEN", "")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="run YOLO on a webcam or the shared MJPEG camera stream.",
        epilog=(
            "the source argument takes precedence over CAMERA_SOURCE. "
            "a plain number opens that local webcam (0, 1, ...); "
            "an http(s)/rtsp URL or a video path is passed through."
        ),
    )
    parser.add_argument(
        "source",
        nargs="?",
        default=None,
        help=(
            "webcam index, camera URL or video path "
            f"(default: {DEFAULT_SOURCE})"
        ),
    )
    parser.add_argument("--model", default=DEFAULT_MODEL, help="path to the YOLO weights")
    parser.add_argument(
        "--conf", type=float, default=0.35, help="minimum confidence (default: 0.35)"
    )
    parser.add_argument(
        "--classes",
        default=DEFAULT_CLASSES,
        help=f"comma-separated classes that trigger an alert (default: {DEFAULT_CLASSES})",
    )
    parser.add_argument(
        "--alert-dir",
        default=DEFAULT_ALERT_DIR,
        help=f"directory for alert snapshots (default: {DEFAULT_ALERT_DIR})",
    )
    parser.add_argument(
        "--alert-cooldown",
        type=float,
        default=5.0,
        help="seconds between alert snapshots (default: 5.0)",
    )
    parser.add_argument(
        "--ingest-url",
        default=DEFAULT_INGEST_URL,
        help="backend incidents endpoint, e.g. http://127.0.0.1:8086/api/v1/incidents "
        "(default: INGEST_URL; empty disables posting)",
    )
    parser.add_argument(
        "--ingest-token",
        default=DEFAULT_INGEST_TOKEN,
        help="X-Ingest-Token for the backend (default: INGEST_API_TOKEN)",
    )
    parser.add_argument(
        "--incident-type",
        default="VEHICLE_IN_ZONE",
        help="incident type sent to the backend (default: VEHICLE_IN_ZONE)",
    )
    parser.add_argument(
        "--no-show", action="store_true", help="do not open a preview window"
    )
    parser.add_argument(
        "--save", action="store_true", help="write annotated output under runs/"
    )
    return parser.parse_args()


def normalize_source(value: str):
    """Turn "0"/"1" into a webcam index, leave URLs and file paths alone."""
    # can use several webcams for test, so have to switch between
    value = value.strip()
    if value.isdigit():
        return int(value)
    return value


def parse_classes(value: str) -> set[str]:
    return {name.strip().lower() for name in value.split(",") if name.strip()}


def save_snapshot(frame, directory: Path) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
    path = directory / f"{stamp}.jpg"
    cv2.imwrite(str(path), frame)  # writes to file (hopefully)
    return path


def post_incident(
    url: str,
    token: str,
    incident_type: str,
    confidence: float,
    label: str,
    snapshot: Path,
) -> None:
    """POST the alert to the Spring backend (POST /api/v1/incidents)."""
    # the API stuff Dsinkerii asked for pls pls pls pls
    payload = {
        "type": incident_type,
        "occurredAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "confidence": round(float(confidence), 3),
        "description": (
            f"Detected {label} on the playground (confidence {confidence:.2f})"
        ),
        "snapshotBase64": base64.b64encode(snapshot.read_bytes()).decode("ascii"),
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Ingest-Token": token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            print(f"[cv] incident posted -> HTTP {response.status}", flush=True)
    except (urllib.error.URLError, OSError) as exc:
        print(f"[cv] incident post failed: {exc}", flush=True)


def matching_detections(result, wanted: set[str], conf: float):
    """Yield (label, confidence) for boxes whose class is in `wanted`."""
    boxes = result.boxes
    if boxes is None:
        return
    names = result.names or {}
    for cls, score in zip(boxes.cls.tolist(), boxes.conf.tolist()):
        label = names.get(int(cls))
        # makes sure it's a car and not a toy
        if label is not None and label.lower() in wanted and score >= conf:
            yield label, float(score)


def main() -> None:
    args = parse_args()
    source = normalize_source(args.source or DEFAULT_SOURCE)
    wanted = parse_classes(args.classes)
    alert_dir = Path(args.alert_dir)

    print(f"[cv] source = {source}", flush=True)
    print(f"[cv] model  = {args.model}", flush=True)
    print(f"[cv] alerts = {sorted(wanted)}", flush=True)

    model = YOLO(args.model)  # initialises model
    # checks for dangerous objects
    # test camera: 'http://109.206.96.58:8080/cam_1.cgi'
    results = model.predict(
        source=source,
        stream=True,
        show=not args.no_show,
        save=args.save,
        conf=args.conf,
        stream_buffer=False,
    )

    last_alert = 0.0
    try:
        for index, result in enumerate(results, start=1):
            now = time.monotonic()
            detections = list(matching_detections(result, wanted, args.conf))

            if detections and now - last_alert >= args.alert_cooldown:
                last_alert = now
                label, confidence = max(detections, key=lambda item: item[1])
                # Reuse the frame YOLO already read instead of opening the
                # camera a second time: a device can only be opened once and a
                # second MJPEG connection would drift from the preview.
                snapshot = save_snapshot(result.orig_img, alert_dir)
                # CAUGHT EM!!! KIDNAPPERS!!!!!!
                print(
                    f"[cv] ALERT {label} ({confidence:.2f}) -> {snapshot}",
                    flush=True,
                )
                if args.ingest_url:
                    post_incident(
                        args.ingest_url,
                        args.ingest_token,
                        args.incident_type,
                        confidence,
                        label,
                        snapshot,
                    )

            if index % 30 == 0:
                boxes = len(result.boxes) if result.boxes is not None else 0
                print(f"[cv] frame {index}: {boxes} object(s)", flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        # Stop the reader threads before the interpreter tears down.
        close = getattr(results, "close", None)
        if callable(close):
            try:
                close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
