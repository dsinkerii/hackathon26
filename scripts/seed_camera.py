"""Create the demo camera entry once the backend is ready.

Runs as a one-shot container in the compose "demo" profile. It is idempotent:
if a camera with the same name already exists it does nothing.
"""

import json
import os
import time
import urllib.error
import urllib.request

BACKEND = os.environ.get("BACKEND_URL", "http://backend:8086").rstrip("/")
USERNAME = os.environ.get("ADMIN_USERNAME", "playground")
PASSWORD = os.environ.get("ADMIN_PASSWORD", "playground-demo")
CAMERA_NAME = os.environ.get("CAMERA_NAME", "Demo camera")
CAMERA_URL = os.environ.get("CAMERA_URL", "http://localhost:8090/stream.mjpg")
LOCATION = os.environ.get("CAMERA_LOCATION", "Docker demo stream")


def request(method, path, payload=None, token=None):
    data = None if payload is None else json.dumps(payload).encode()
    headers = {"Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        BACKEND + path, data=data, headers=headers, method=method
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        body = response.read()
        return response.status, (json.loads(body) if body else None)


def login():
    last_error = None
    for attempt in range(1, 61):
        try:
            status, body = request(
                "POST",
                "/api/v1/auth/login",
                {"username": USERNAME, "password": PASSWORD},
            )
            if status == 200 and body and body.get("accessToken"):
                print(f"[seed] logged in as {USERNAME!r}", flush=True)
                return body["accessToken"]
        except Exception as error:  # noqa: BLE001 - retry on anything transient
            last_error = error
        if attempt % 5 == 0:
            print(f"[seed] waiting for backend ({attempt})...", flush=True)
        time.sleep(2)
    raise SystemExit(f"[seed] backend did not become ready: {last_error}")


def main():
    token = login()

    _, cameras = request("GET", "/api/v1/cameras", token=token)
    existing = {str(c.get("name", "")).casefold() for c in cameras or []}
    if CAMERA_NAME.casefold() in existing:
        print(f"[seed] camera {CAMERA_NAME!r} already exists", flush=True)
        return

    try:
        request(
            "POST",
            "/api/v1/cameras",
            {
                "name": CAMERA_NAME,
                "location": LOCATION,
                "streamUrl": CAMERA_URL,
                "enabled": True,
            },
            token=token,
        )
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        print(f"[seed] could not add camera: {error.code} {detail}", flush=True)
        raise SystemExit(1)

    print(f"[seed] added camera {CAMERA_NAME!r} -> {CAMERA_URL}", flush=True)


if __name__ == "__main__":
    main()
