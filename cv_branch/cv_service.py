from __future__ import annotations

import argparse
import os

from ultralytics import YOLO

DEFAULT_SOURCE = os.environ.get("CAMERA_SOURCE", "http://127.0.0.1:8090/stream.mjpg")
DEFAULT_MODEL = os.environ.get("YOLO_MODEL", "yolo26n.pt")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="run YOLO on the shared camera stream.",
        epilog="the source argument takes precedence over CAMERA_SOURCE.",
    )
    parser.add_argument(
        "source",
        nargs="?",
        default=None,
        help=f"camera URL or video path (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL, help="path to the YOLO weights")
    parser.add_argument(
        "--conf", type=float, default=0.35, help="minimum confidence (default: 0.35)"
    )
    parser.add_argument(
        "--no-show", action="store_true", help="do not open a preview window"
    )
    parser.add_argument(
        "--save", action="store_true", help="write annotated output under runs/"
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = args.source or DEFAULT_SOURCE

    print(f"[cv] source = {source}", flush=True)
    print(f"[cv] model  = {args.model}", flush=True)

    model = YOLO(args.model)
    results = model.predict(
        source=source,
        stream=True,
        show=not args.no_show,
        save=args.save,
        conf=args.conf,
    )

    try:
        for index, result in enumerate(results, start=1):
            boxes = len(result.boxes) if result.boxes is not None else 0
            if index % 30 == 0:
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
