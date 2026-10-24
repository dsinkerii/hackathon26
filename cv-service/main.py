"""Safe Playground CV service entry point.

Modes:
  * simulator (default) — synthesizes car/stranger events and pushes them to
    the Java backend. Zero heavy dependencies; lets the whole demo chain
    (CV -> backend -> operator console) run anywhere.
  * video / camera — real pipeline: OpenCV frames -> YOLO tracking ->
    zone check -> snapshots -> ingest. Requires `requirements-cv.txt`.

Examples (from this folder):
  py main.py --dry-run            # one sample event, no HTTP call
  py main.py --once               # one sample event, posted to the backend
  py main.py --interval 8         # simulator loop faster
  INGEST_API_TOKEN=secret py main.py --source camera
"""
from __future__ import annotations

import argparse
import sys

from app.pipeline import run as run_pipeline
from app.publisher import publish_event
from app.settings import load_settings
from app.simulator import run as run_simulator


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.partition("\n\n")[0])
    parser.add_argument("--config", default=None, help="path to config.yaml")
    parser.add_argument(
        "--source",
        choices=("simulator", "video", "camera"),
        default=None,
        help="override source.mode from the config",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=None,
        help="override events.interval_seconds (simulator mode)",
    )
    parser.add_argument(
        "--once", action="store_true", help="publish exactly one event and exit (simulator)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print events instead of posting them"
    )
    args = parser.parse_args(argv)

    settings = load_settings(
        args.config,
        mode_override=args.source,
        interval_override=args.interval,
    )

    if settings.mode == "simulator":
        run_simulator(
            settings,
            lambda event: publish_event(event, settings, dry_run=args.dry_run),
            once=args.once or args.dry_run,
        )
    else:
        if args.dry_run:
            print("[main] --dry-run has no effect in video/camera modes.")
        try:
            run_pipeline(settings, lambda event: publish_event(event, settings))
        except (ImportError, RuntimeError) as error:
            print(f"[main] Pipeline failed: {error}")
            print("[main] Hint: install `pip install -r requirements-cv.txt` "
                  "or run with --source simulator.")
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
