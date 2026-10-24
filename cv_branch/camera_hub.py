#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Optional

import cv2


def _is_device(source) -> bool:
    return isinstance(source, int)


def _is_file(source) -> bool:
    if not isinstance(source, str):
        return False
    lowered = source.lower()
    return not lowered.startswith(("rtsp://", "rtsps://", "http://", "https://"))


class CameraHub:
    def __init__(self, source, width=1280, height=720, fps=30, quality=80, loop=False,
                 fourcc="MJPG"):
        self.source = source
        self.width = width
        self.height = height
        self.fps = max(1, fps)
        self.quality = quality
        self.loop = loop
        self.fourcc = fourcc

        self._frame: Optional[bytes] = None
        self._seq = 0
        self._cond = threading.Condition()
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None

        self.error: Optional[str] = None
        self.measured_fps = 0.0

    def start(self) -> "CameraHub":
        self._thread = threading.Thread(
            target=self._capture, name="camera-hub", daemon=True
        )
        self._thread.start()
        return self

    def stop(self) -> None:
        self._stop.set()
        with self._cond:
            self._cond.notify_all()

    @property
    def stopping(self) -> bool:
        return self._stop.is_set()

    def latest(self) -> tuple[int, Optional[bytes]]:
        with self._cond:
            return self._seq, self._frame

    def wait_for_frame(
        self, after_seq: int, timeout: float = 2.0
    ) -> tuple[int, Optional[bytes]]:
        with self._cond:
            if self._seq == after_seq:
                self._cond.wait(timeout)
            return self._seq, self._frame

    def _open(self):
        cap = cv2.VideoCapture(self.source)
        if not cap.isOpened():
            cap.release()
            return None
        if _is_device(self.source) and self.fourcc:
            cap.set(
                cv2.CAP_PROP_FOURCC,
                cv2.VideoWriter_fourcc(*self.fourcc[:4].ljust(4)),
            )
        if self.width:
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        if self.height:
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        cap.set(cv2.CAP_PROP_FPS, self.fps)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return cap

    def _capture(self) -> None:
        cap = None
        pace = _is_file(self.source)
        frame_time = 1.0 / self.fps
        started = time.monotonic()
        counted = 0

        while not self._stop.is_set():
            if cap is None:
                cap = self._open()
                if cap is None:
                    self.error = f"cannot open source {self.source!r}"
                    self._stop.wait(2.0)
                    continue
                self.error = None

            ok, frame = cap.read()
            if not ok or frame is None:
                if self.loop and pace:
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                cap.release()
                cap = None
                self.error = "frame read failed"
                self._stop.wait(0.5)
                continue

            ok, buffer = cv2.imencode(
                ".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), self.quality]
            )
            if not ok:
                continue

            with self._cond:
                self._frame = buffer.tobytes()
                self._seq += 1
                self._cond.notify_all()

            counted += 1
            now = time.monotonic()
            if now - started >= 1.0:
                self.measured_fps = counted / (now - started)
                counted = 0
                started = now

            if pace:
                time.sleep(frame_time)

        if cap is not None:
            cap.release()


class HubServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, hub: CameraHub):
        super().__init__(address, Handler)
        self.hub = hub


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "camera-hub"

    def log_message(self, fmt, *args):
        pass

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")

    def _send(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status: int, payload: dict) -> None:
        self._send(status, "application/json", json.dumps(payload).encode())

    # bullcrap to send if this link is used elsewhere
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/stream.mjpg", "/stream", "/video"):
            self._stream()
        elif path in ("/snapshot.jpg", "/snapshot"):
            _, frame = self.server.hub.latest()
            if frame is None:
                self._json(503, {"error": "no frame yet"})
            else:
                self._send(200, "image/jpeg", frame)
        elif path == "/health":
            hub = self.server.hub
            self._json(
                200,
                {
                    "ready": hub.latest()[1] is not None,
                    "source": str(hub.source),
                    "fps": round(hub.measured_fps, 1),
                    "error": hub.error,
                },
            )
        elif path == "/":
            self._send(200, "text/html; charset=utf-8", INDEX_HTML)
        else:
            self._json(404, {"error": "not found"})

    def _stream(self) -> None:
        hub = self.server.hub
        self.close_connection = True
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
        self.send_header("Connection", "close")
        self.end_headers()

        last = -1
        try:
            while not hub.stopping:
                seq, frame = hub.wait_for_frame(last, timeout=2.0)
                if frame is None or seq == last:
                    continue
                last = seq
                self.wfile.write(b"--frame\r\n")
                self.wfile.write(b"Content-Type: image/jpeg\r\n")
                self.wfile.write(b"Content-Length: " + str(len(frame)).encode())
                self.wfile.write(b"\r\n\r\n")
                self.wfile.write(frame)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
# if opened in browser

INDEX_HTML = b"""<!doctype html>
<html><head><meta charset="utf-8"><title>camera hub</title>
<style>html,body{margin:0;height:100%;background:#111}
img{width:100%;height:100%;object-fit:contain;display:block}</style></head>
<body><img src="/stream.mjpg" alt="camera"></body></html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="MJPEG camera hub")
    parser.add_argument(
        "--source",
        default="0",
        help="camera index, device path, RTSP URL or video file (default: 0)",
    )
    parser.add_argument("--host", default="0.0.0.0", help="bind address")
    parser.add_argument("--port", type=int, default=8090, help="HTTP port")
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--quality", type=int, default=80, help="JPEG quality 1-95")
    parser.add_argument(
        "--fourcc",
        default="MJPG",
        help="camera pixel format for device sources (default MJPG, use '' to skip)",
    )
    parser.add_argument("--loop", action="store_true", help="loop file sources")
    args = parser.parse_args()

    source = int(args.source) if args.source.isdigit() else args.source
    if isinstance(source, str) and _is_device(source):
        source = int(source)

    hub = CameraHub(
        source,
        width=args.width,
        height=args.height,
        fps=args.fps,
        quality=args.quality,
        loop=args.loop,
        fourcc=args.fourcc,
    ).start()

    server = HubServer((args.host, args.port), hub)
    print(
        f"[camera-hub] source={source!r}  http://{args.host}:{args.port}/stream.mjpg",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        hub.stop()
        server.server_close()


if __name__ == "__main__":
    main()
