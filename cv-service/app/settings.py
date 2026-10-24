"""Configuration loading for the CV service.

Order of priority: CLI flags > environment variables > config.yaml > defaults.
PyYAML is optional: if it is not installed the service still runs in simulator
mode on built-in defaults.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_API_URL = "http://localhost:8080"

DEFAULT_POLYGON = [[0.05, 0.55], [0.95, 0.55], [0.95, 0.95], [0.05, 0.95]]

SOURCE_MODES = ("simulator", "video", "camera")


@dataclass
class Settings:
    api_url: str = DEFAULT_API_URL
    ingest_token: str = ""
    mode: str = "simulator"
    video_path: str = "../data/videos/test.mp4"
    camera_index: int = 0
    interval_seconds: float = 14.0
    cooldown_seconds: float = 60.0
    detection_confidence: float = 0.5
    polygon: list[list[float]] = field(default_factory=lambda: [list(p) for p in DEFAULT_POLYGON])


def load_settings(
    config_path: str | None = None,
    *,
    mode_override: str | None = None,
    interval_override: float | None = None,
) -> Settings:
    """Builds settings from config.yaml plus environment and CLI overrides."""
    settings = Settings()

    config = _read_config(config_path)
    if config:
        backend = config.get("backend", {})
        settings.api_url = str(backend.get("url", settings.api_url))
        source = config.get("source", {})
        settings.mode = str(source.get("mode", settings.mode))
        settings.video_path = str(source.get("video_path", settings.video_path))
        settings.camera_index = int(source.get("camera_index", settings.camera_index))
        events = config.get("events", {})
        settings.interval_seconds = float(events.get("interval_seconds", settings.interval_seconds))
        settings.cooldown_seconds = float(events.get("cooldown_seconds", settings.cooldown_seconds))
        settings.detection_confidence = float(
            events.get("detection_confidence", settings.detection_confidence)
        )
        polygon = config.get("zone", {}).get("polygon")
        if polygon:
            settings.polygon = [list(map(float, point)) for point in polygon]

    if os.environ.get("PLAYGROUND_API_URL"):
        settings.api_url = os.environ["PLAYGROUND_API_URL"]
    if os.environ.get("INGEST_API_TOKEN"):
        settings.ingest_token = os.environ["INGEST_API_TOKEN"]
    if mode_override:
        settings.mode = mode_override
    if interval_override is not None:
        settings.interval_seconds = interval_override

    if settings.mode not in SOURCE_MODES:
        raise ValueError(
            f"Unknown source mode '{settings.mode}'. Expected one of {SOURCE_MODES}."
        )
    return settings


def _read_config(config_path: str | None) -> dict:
    if not config_path:
        return {}
    path = Path(config_path)
    if not path.is_file():
        raise FileNotFoundError(f"Config file not found: {path}")
    try:
        import yaml
    except ImportError:
        print("[settings] PyYAML is not installed — ignoring config file, using defaults.")
        return {}
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Config file {path} must contain a YAML mapping.")
    return data
