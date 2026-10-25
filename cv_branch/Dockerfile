# syntax=docker/dockerfile:1

# The demo stream is generated instead of shipped as a binary, so the image
# always contains the same synthetic clip and no copyrighted footage.
FROM debian:bookworm-slim AS media
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*
RUN ffmpeg -hide_banner -loglevel error \
    -f lavfi -i testsrc2=size=1280x720:rate=25 -t 20 \
    -pix_fmt yuv420p -c:v libx264 -movflags +faststart \
    -y /demo.mp4

FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1

# opencv needs libglib and OpenMP even in headless builds.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# headless: there is no display inside the container.
RUN pip install --no-cache-dir "opencv-python-headless>=4.10,<6"

COPY camera_hub.py ./
COPY --from=media /demo.mp4 /app/demo.mp4

EXPOSE 8090

CMD ["python", "camera_hub.py", \
     "--source", "/app/demo.mp4", \
     "--loop", \
     "--host", "0.0.0.0", \
     "--port", "8090"]
