"""Synthetic event source: makes the full demo chain work without any ML setup.

Mixes car alarms with stranger visits and pushes JPEG-less events, which the
backend accepts fine (snapshots are optional there).
"""
from __future__ import annotations

import itertools
import random
import time
from datetime import datetime, timezone

CAR_TYPES = ("CAR_ON_PLAYGROUND",)
STRANGER_TYPES = ("STRANGER_DETECTED",)

CAR = "car"
STRANGER = "stranger"


def snapshot(now: datetime | None = None) -> str:
    """ISO-8601 UTC timestamp in the backend ingest format."""
    stamp = now or datetime.now(timezone.utc)
    return stamp.isoformat()


def make_event(kind: str, car_counter: itertools.count, now: datetime | None = None) -> dict:
    if kind == CAR:
        track_id = f"car-{next(car_counter)}"
        return {
            "type": random.choice(CAR_TYPES),
            "occurredAt": snapshot(now),
            "trackId": track_id,
            "confidence": round(random.uniform(0.75, 0.97), 2),
        }
    return {
        "type": STRANGER_TYPES[0],
        "occurredAt": snapshot(now),
        "trackId": f"track-stranger-{next(itertools.count())}",
        "confidence": round(random.uniform(0.55, 0.85), 2),
    }


def run(settings, publish, *, once: bool = False) -> None:
    car_counter = itertools.count(1)
    if once:
        publish(make_event(CAR if random.random() < 0.35 else STRANGER, car_counter))
        return

    print(
        f"[simulator] Publishing a synthetic event every ~{settings.interval_seconds:.0f}s "
        f"to {settings.api_url}. Ctrl+C to stop."
    )
    try:
        while True:
            kind = CAR if random.random() < 0.35 else STRANGER
            publish(make_event(kind, car_counter))
            jitter = random.uniform(0.7, 1.3)
            time.sleep(settings.interval_seconds * jitter)
    except KeyboardInterrupt:
        print("[simulator] Stopped.")
