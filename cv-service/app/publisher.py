"""HTTP publisher for playground events.

Uses the standard library only, so the simulator mode works out of the box.
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request


def publish_event(event: dict, settings, *, dry_run: bool = False) -> bool:
    """Posts one event to the backend ingest endpoint.

    Returns True when the backend accepted (2xx) or the event matched its
    deduplication window (also 2xx per the current backend contract).
    """
    payload = json.dumps(event).encode("utf-8")
    if dry_run:
        print("[publisher] DRY RUN:", payload.decode("utf-8"))
        return True

    url = settings.api_url.rstrip("/") + "/api/v1/incidents"
    request = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-Ingest-Token": settings.ingest_token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body = response.read().decode("utf-8", errors="replace")
            print(f"[publisher] {event['type']} accepted (HTTP {response.status})")
            print(f"[publisher]   {body}")
            return True
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        print(f"[publisher] Backend rejected event {event['type']}: HTTP {error.code}")
        print(f"[publisher]   {detail}")
    except urllib.error.URLError as error:
        print(
            f"[publisher] Cannot reach backend at {settings.api_url}: {error.reason}. "
            "Is the backend running?"
        )
    return False
