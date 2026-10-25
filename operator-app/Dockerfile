# syntax=docker/dockerfile:1

# Pin the SDK so a fresh machine builds the same artifacts. The Flutter
# version must stay compatible with pubspec.lock.
ARG FLUTTER_VERSION=3.38.5
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build

# `/` makes the app call the same origin; nginx proxies those calls to the API.
ARG API_BASE_URL=/

WORKDIR /app

# Warm the pub cache before copying sources so code changes do not refetch
# every package.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY lib ./lib
COPY web ./web
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- runtime -------------------------------------------------------------
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
