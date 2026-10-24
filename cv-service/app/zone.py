"""Playground restrictive zone helpers."""
from __future__ import annotations


def scale(polygon, width: int, height: int) -> list[tuple[float, float]]:
    """Converts normalized 0..1 coordinates into frame pixels."""
    return [(float(x) * width, float(y) * height) for x, y in polygon]


def contains(polygon, x: float, y: float) -> bool:
    """Point-in-polygon by ray casting. `polygon` is a list of (px, py)."""
    inside = False
    count = len(polygon)
    if count < 3:
        return False
    j = count - 1
    for i in range(count):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside
